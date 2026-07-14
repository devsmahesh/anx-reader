import 'package:anx_reader/config/api_config.dart';
import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/models/catalog_book.dart';
import 'package:dio/dio.dart';

class BooksApiException implements Exception {
  BooksApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BooksApi {
  BooksApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

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
  }) async {
    final token = Prefs().accessToken;
    if (token == null || token.isEmpty) {
      throw BooksApiException('Not signed in');
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

      throw BooksApiException(
        _extractMessage(response.data) ?? 'Failed to load books',
      );
    } on BooksApiException {
      rethrow;
    } on DioException catch (e) {
      throw BooksApiException(_dioErrorMessage(e));
    } catch (e) {
      throw BooksApiException(e.toString());
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String? _extractMessage(dynamic data) {
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return null;
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
