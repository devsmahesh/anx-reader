import 'dart:io';
import 'dart:typed_data';

import 'package:anx_reader/dao/book.dart';
import 'package:anx_reader/models/book.dart';
import 'package:anx_reader/models/catalog_book.dart';
import 'package:anx_reader/service/auth/auth_api.dart';
import 'package:anx_reader/service/book.dart';
import 'package:anx_reader/service/book_decrypt/book_decrypt_service.dart';
import 'package:anx_reader/utils/get_path/get_base_path.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// Downloads, decrypts (every open), and opens a purchased/library book.
/// Decrypted bytes are written only to a temp file and deleted after reading.
class CatalogBookOpener {
  CatalogBookOpener({
    Dio? dio,
    AuthApi? authApi,
  })  : _dio = dio ?? Dio(),
        _authApi = authApi ?? AuthApi();

  final Dio _dio;
  final AuthApi _authApi;

  Future<void> open(
    WidgetRef ref,
    BuildContext context,
    CatalogBook catalogBook,
  ) async {
    try {
      await _openInternal(ref, context, catalogBook);
    } on CatalogBookOpenException {
      rethrow;
    } on BookDecryptException catch (e) {
      AnxLog.severe('CatalogOpen decrypt failed: $e');
      throw CatalogBookOpenException(
        'Unable to decrypt this book. Please try again or contact support.',
      );
    } on DioException catch (e) {
      AnxLog.severe('CatalogOpen network failed: $e');
      throw CatalogBookOpenException(_messageForDio(e));
    } catch (e, st) {
      AnxLog.severe('CatalogOpen failed: $e\n$st');
      throw CatalogBookOpenException(
        'Unable to open this book. Please try again.',
      );
    }
  }

  Future<void> _openInternal(
    WidgetRef ref,
    BuildContext context,
    CatalogBook catalogBook,
  ) async {
    if (catalogBook.id.isEmpty) {
      throw CatalogBookOpenException('Book details are incomplete.');
    }
    if (catalogBook.bookFileUrl == null || catalogBook.bookFileUrl!.isEmpty) {
      throw CatalogBookOpenException(
        'Book file is unavailable. Please contact support.',
      );
    }
    if (catalogBook.encryptionKey == null ||
        catalogBook.encryptionKey!.isEmpty ||
        catalogBook.encryptionIv == null ||
        catalogBook.encryptionIv!.isEmpty) {
      throw CatalogBookOpenException(
        'Book encryption data is missing. Please re-purchase or contact support.',
      );
    }

    final userId = await _authApi.resolveUserId();
    if (userId == null || userId.isEmpty) {
      throw CatalogBookOpenException(
        'User data not found. Please login again.',
      );
    }

    AnxLog.info(
      'CatalogOpen: downloading ${catalogBook.bookFileUrl} (userId=$userId)',
    );
    final encryptedBytes = await _downloadBytes(catalogBook.bookFileUrl!);

    AnxLog.info('CatalogOpen: decrypting ${catalogBook.title}');
    final decryptedBytes = BookDecryptService.decryptBookBytes(
      userId: userId,
      encryptionKeyHex: catalogBook.encryptionKey!,
      encryptionIvHex: catalogBook.encryptionIv!,
      encryptedFileBytes: encryptedBytes,
    );
    AnxLog.info('CatalogOpen: decrypted ${decryptedBytes.length} bytes');

    final extension = _extensionFromUrl(catalogBook.bookFileUrl!);
    final tempRelativePath = 'temp/catalog-${catalogBook.id}.$extension';
    final tempFullPath = getBasePath(tempRelativePath);
    File? tempFile;

    try {
      await Directory(p.dirname(tempFullPath)).create(recursive: true);
      tempFile = File(tempFullPath);
      await tempFile.writeAsBytes(decryptedBytes, flush: true);

      // Remove any previously cached bookshelf copy from earlier versions.
      await _removeLegacyCache(catalogBook.id);

      final coverRelativePath =
          await _cacheRemoteCover(catalogBook);

      final book = Book(
        id: -1,
        title: catalogBook.title,
        coverPath: coverRelativePath ?? '',
        filePath: tempRelativePath,
        lastReadPosition: '',
        readingPercentage: 0,
        author: catalogBook.authorLabel,
        isDeleted: false,
        description: catalogBook.description,
        rating: 0.0,
        md5: null,
        createTime: DateTime.now(),
        updateTime: DateTime.now(),
      );

      if (!context.mounted) return;
      await pushToReadingPage(ref, context, book);
    } finally {
      await _deleteTempFile(tempFile);
    }
  }

  Future<void> _removeLegacyCache(String bookId) async {
    try {
      final cached = await bookDao.getBookByMd5('graphe-$bookId');
      if (cached == null) return;
      final file = File(cached.fileFullPath);
      if (file.existsSync()) {
        await file.delete();
      }
      cached.isDeleted = true;
      await bookDao.updateBook(cached);
    } catch (e) {
      AnxLog.warning('CatalogOpen: legacy cache cleanup failed: $e');
    }
  }

  /// Downloads a remote cover into the local cover cache when available.
  /// Returns a relative path like `cover/catalog-{id}.jpg`, or null.
  Future<String?> _cacheRemoteCover(CatalogBook catalogBook) async {
    final url = catalogBook.coverImageUrl;
    if (url == null || url.isEmpty) return null;

    try {
      final ext = _coverExtensionFromUrl(url);
      final relativePath = 'cover/catalog-${catalogBook.id}.$ext';
      final fullPath = getBasePath(relativePath);
      final file = File(fullPath);

      if (await file.exists() && await file.length() > 0) {
        return relativePath;
      }

      await Directory(p.dirname(fullPath)).create(recursive: true);
      final bytes = await _downloadBytes(url);
      if (bytes.isEmpty) return null;
      await file.writeAsBytes(bytes, flush: true);
      AnxLog.info('CatalogOpen: cached cover for ${catalogBook.id}');
      return relativePath;
    } catch (e) {
      AnxLog.warning('CatalogOpen: cover cache failed: $e');
      return null;
    }
  }

  String _coverExtensionFromUrl(String url) {
    try {
      final path = Uri.parse(url).path.toLowerCase();
      final ext = p.extension(path);
      if (ext == '.png' ||
          ext == '.jpg' ||
          ext == '.jpeg' ||
          ext == '.webp' ||
          ext == '.gif') {
        return ext.replaceFirst('.', '');
      }
    } catch (_) {}
    return 'jpg';
  }

  Future<void> _deleteTempFile(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) {
        await file.delete();
        AnxLog.info('CatalogOpen: removed temp decrypted file');
      }
    } catch (e) {
      AnxLog.warning('CatalogOpen: temp file cleanup failed: $e');
    }
  }

  Future<Uint8List> _downloadBytes(String url) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw CatalogBookOpenException(
          'Book file is empty or unavailable.',
        );
      }
      return Uint8List.fromList(data);
    } on DioException catch (e) {
      throw CatalogBookOpenException(_messageForDio(e));
    }
  }

  String _messageForDio(DioException e) {
    final status = e.response?.statusCode;
    if (status == 404) {
      return 'Book file not found. It may have been removed or the link is broken.';
    }
    if (status == 401 || status == 403) {
      return 'You do not have access to this book file. Please login again.';
    }
    if (status != null && status >= 500) {
      return 'Server error while downloading the book. Please try again later.';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Download timed out. Check your connection and try again.';
      case DioExceptionType.connectionError:
        return 'Unable to connect. Check your internet connection.';
      default:
        return 'Failed to download the book. Please try again.';
    }
  }

  String _extensionFromUrl(String url) {
    try {
      final path = Uri.parse(url).path;
      final ext = p.extension(path).toLowerCase();
      if (ext == '.pdf') return 'pdf';
      if (ext == '.epub') return 'epub';
      if (ext.isNotEmpty && ext.length <= 5) {
        return ext.replaceFirst('.', '');
      }
    } catch (_) {}
    return 'epub';
  }
}

class CatalogBookOpenException implements Exception {
  CatalogBookOpenException(this.message);

  final String message;

  @override
  String toString() => message;
}
