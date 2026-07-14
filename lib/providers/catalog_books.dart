import 'package:anx_reader/models/catalog_book.dart';
import 'package:anx_reader/service/books/books_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final booksApiProvider = Provider<BooksApi>((ref) => BooksApi());

enum CatalogSource { purchased, library }

class CatalogBooksState {
  const CatalogBooksState({
    required this.books,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
    required this.search,
    this.isLoadingMore = false,
  });

  final List<CatalogBook> books;
  final int currentPage;
  final int totalPages;
  final int totalRecords;
  final String search;
  final bool isLoadingMore;

  bool get hasMore => currentPage < totalPages;

  CatalogBooksState copyWith({
    List<CatalogBook>? books,
    int? currentPage,
    int? totalPages,
    int? totalRecords,
    String? search,
    bool? isLoadingMore,
  }) {
    return CatalogBooksState(
      books: books ?? this.books,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalRecords: totalRecords ?? this.totalRecords,
      search: search ?? this.search,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class CatalogBooksNotifier
    extends StateNotifier<AsyncValue<CatalogBooksState>> {
  CatalogBooksNotifier(this._api, this._source)
      : super(const AsyncValue.loading()) {
    refresh();
  }

  final BooksApi _api;
  final CatalogSource _source;
  static const int _pageSize = 20;

  Future<CatalogBookPage> _fetch({
    required int page,
    required String search,
  }) {
    switch (_source) {
      case CatalogSource.purchased:
        return _api.getPurchasedBooks(
          page: page,
          limit: _pageSize,
          search: search,
        );
      case CatalogSource.library:
        return _api.getLibraryBooks(
          page: page,
          limit: _pageSize,
          search: search,
        );
    }
  }

  Future<void> refresh({String? search}) async {
    final query = search ?? state.valueOrNull?.search ?? '';
    state = const AsyncValue.loading();
    try {
      final page = await _fetch(page: 1, search: query);
      state = AsyncValue.data(
        CatalogBooksState(
          books: page.books,
          currentPage: page.currentPage,
          totalPages: page.totalPages,
          totalRecords: page.totalRecords,
          search: query,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> search(String query) => refresh(search: query.trim());

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final nextPage = await _fetch(
        page: current.currentPage + 1,
        search: current.search,
      );
      state = AsyncValue.data(
        current.copyWith(
          books: [...current.books, ...nextPage.books],
          currentPage: nextPage.currentPage,
          totalPages: nextPage.totalPages,
          totalRecords: nextPage.totalRecords,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final purchasedBooksProvider = StateNotifierProvider<CatalogBooksNotifier,
    AsyncValue<CatalogBooksState>>((ref) {
  return CatalogBooksNotifier(
    ref.watch(booksApiProvider),
    CatalogSource.purchased,
  );
});

final libraryBooksProvider = StateNotifierProvider<CatalogBooksNotifier,
    AsyncValue<CatalogBooksState>>((ref) {
  return CatalogBooksNotifier(
    ref.watch(booksApiProvider),
    CatalogSource.library,
  );
});
