import 'package:anx_reader/config/api_config.dart';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/models/catalog_book.dart';
import 'package:anx_reader/service/auth/auth_api.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:dio/dio.dart';

class BooksApiException implements Exception {
  BooksApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BooksApi {
  BooksApi({Dio? dio, AuthApi? authApi})
      : _dio = dio ?? Dio(),
        _authApi = authApi ?? AuthApi();

  final Dio _dio;
  final AuthApi _authApi;

  Future<CatalogBookPage> getPurchasedBooks({
    int page = 1,
    int limit = 20,
    String search = '',
  }) {
    return _fetchCatalog(
      path: '/books/purchasedBooks',
      page: page,
      limit: limit,
      search: search,
    );
  }

  Future<CatalogBookPage> getLibraryBooks({
    int page = 1,
    int limit = 20,
    String search = '',
    String sort = 'all',
  }) {
    return _fetchCatalog(
      path: '/library',
      page: page,
      limit: limit,
      search: search,
      extraQuery: {'sort': sort},
    );
  }

  Future<CatalogBookPage> _fetchCatalog({
    required String path,
    required int page,
    required int limit,
    required String search,
    Map<String, dynamic>? extraQuery,
    bool didRefresh = false,
  }) async {
    final token = Prefs().accessToken;
    if (token == null || token.isEmpty) {
      // Not signed in — same UX as External Lib empty shelf.
      return _emptyPage(page: page, limit: limit);
    }

    try {
      final response = await _dio.get(
        '${ApiConfig.apiBaseUrl}$path',
        queryParameters: {
          'page': page,
          'limit': limit,
          'search': search,
          ...?extraQuery,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      AnxLog.info(
        'BooksApi $path -> ${response.statusCode} '
        '(dataType=${response.data.runtimeType})',
      );

      // Expired / invalid session: refresh once, then treat as empty catalog.
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (!didRefresh) {
          final refreshed = await _authApi.refreshSession();
          if (refreshed) {
            return _fetchCatalog(
              path: path,
              page: page,
              limit: limit,
              search: search,
              extraQuery: extraQuery,
              didRefresh: true,
            );
          }
        }
        return _emptyPage(page: page, limit: limit);
      }

      // 404 / not-found payloads → empty catalog (External Lib style).
      if (response.statusCode == 404 || _isNotFoundPayload(response.data)) {
        return _emptyPage(page: page, limit: limit);
      }

      if (response.statusCode == 200 && response.data is Map) {
        final body = Map<String, dynamic>.from(response.data as Map);
        final rawList = body['data'];
        final books = <CatalogBook>[];
        if (rawList is List) {
          for (final item in rawList) {
            if (item is Map) {
              books.add(
                CatalogBook.fromPurchasedJson(
                  Map<String, dynamic>.from(item),
                ),
              );
            }
          }
        }

        final pagination = body['pagination'] is Map
            ? Map<String, dynamic>.from(body['pagination'] as Map)
            : <String, dynamic>{};

        return CatalogBookPage(
          books: books,
          currentPage: _asInt(pagination['currentPage']) ?? page,
          totalPages: _asInt(pagination['totalPages']) ?? 1,
          totalRecords: _asInt(pagination['totalRecords']) ?? books.length,
          limit: _asInt(pagination['limit']) ?? limit,
        );
      }

      // Unknown soft failure without a useful message → show empty, not Retry.
      final message = _extractMessage(response.data);
      if (message == null || _isNotFoundMessage(message)) {
        return _emptyPage(page: page, limit: limit);
      }

      throw BooksApiException(message);
    } on BooksApiException {
      rethrow;
    } on DioException catch (e) {
      throw BooksApiException(_dioErrorMessage(e));
    } catch (e) {
      throw BooksApiException(e.toString());
    }
  }

  CatalogBookPage _emptyPage({required int page, required int limit}) {
    return CatalogBookPage(
      books: const [],
      currentPage: page,
      totalPages: 0,
      totalRecords: 0,
      limit: limit,
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String? _extractMessage(dynamic data) {
    if (data is Map) {
      if (data['message'] != null) return data['message'].toString();
      if (data['error'] != null) return data['error'].toString();
    }
    return null;
  }

  bool _isNotFoundMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('not found') ||
        lower.contains('no books') ||
        lower.contains('no purchased') ||
        lower.contains('no library');
  }

  bool _isNotFoundPayload(dynamic data) {
    final message = _extractMessage(data);
    return message != null && _isNotFoundMessage(message);
  }

  String _dioErrorMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Unable to connect to the server. Check that the API is running.';
    }
    return _extractMessage(e.response?.data) ??
        e.message ??
        'Request failed. Please try again.';
  }
}
