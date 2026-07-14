import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/models/catalog_book.dart';
import 'package:anx_reader/providers/catalog_books.dart';
import 'package:anx_reader/service/books/catalog_book_opener.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/common/container/filled_container.dart';
import 'package:anx_reader/widgets/show_loading.dart';
import 'package:anx_reader/widgets/tips/bookshelf_tips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class CatalogBooksPage extends ConsumerStatefulWidget {
  const CatalogBooksPage({
    super.key,
    required this.provider,
    this.controller,
    this.emptyMessage,
  });

  final StateNotifierProvider<CatalogBooksNotifier,
      AsyncValue<CatalogBooksState>> provider;
  final ScrollController? controller;
  final String? emptyMessage;

  @override
  ConsumerState<CatalogBooksPage> createState() => _CatalogBooksPageState();
}

class _CatalogBooksPageState extends ConsumerState<CatalogBooksPage> {
  late final ScrollController _scrollController =
      widget.controller ?? ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _ownsScrollController = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _ownsScrollController = widget.controller == null;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_ownsScrollController) {
      _scrollController.dispose();
    }
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      ref.read(widget.provider.notifier).loadMore();
    }
  }

  void _submitSearch(String value) {
    ref.read(widget.provider.notifier).search(value);
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(widget.provider.notifier).search('');
    setState(() {});
  }

  Future<void> _openBook(CatalogBook book) async {
    if (_opening) return;
    _opening = true;
    showLoading();
    try {
      await CatalogBookOpener().open(ref, context, book);
    } on CatalogBookOpenException catch (e) {
      AnxToast.show(e.message);
    } catch (e) {
      AnxToast.show('Unable to open this book. Please try again.');
    } finally {
      SmartDialog.dismiss();
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(widget.provider);

    final PreferredSizeWidget appBar = AppBar(
      forceMaterialTransparency: true,
      title: Container(
        height: 34,
        constraints: const BoxConstraints(maxWidth: 400),
        child: FilledContainer(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: Theme.of(context).colorScheme.surface.withAlpha(80),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _submitSearch,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: L10n.of(context).searchBooksOrNotes,
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: _clearSearch,
                  child: Icon(
                    Icons.clear,
                    size: 18,
                    color: Theme.of(context).hintColor,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: L10n.of(context).commonRefresh,
          onPressed: () => ref.read(widget.provider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    );

    final emptyTitle =
        widget.emptyMessage ?? L10n.of(context).catalogNoBooks;

    final Widget body = asyncState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        // 404 / "not found" should look like External Lib empty state.
        if (_isCatalogNotFoundError(error)) {
          return BookshelfTips(
            title: emptyTitle,
            showSubtitle: false,
          );
        }
        return _ErrorView(
          message: error.toString(),
          onRetry: () => ref.read(widget.provider.notifier).refresh(),
        );
      },
      data: (data) {
        if (data.books.isEmpty) {
          return BookshelfTips(
            title: emptyTitle,
            showSubtitle: false,
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(widget.provider.notifier).refresh(),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.62,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _CatalogBookTile(
                        book: data.books[index],
                        onTap: () => _openBook(data.books[index]),
                      );
                    },
                    childCount: data.books.length,
                  ),
                ),
              ),
              if (data.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        );
      },
    );

    return Container(
      decoration: Prefs().eInkMode
          ? null
          : BoxDecoration(
              gradient: RadialGradient(
                tileMode: TileMode.clamp,
                center: Alignment.topRight,
                radius: 1,
                colors: [
                  Theme.of(context).colorScheme.primary.withAlpha(5),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
              ),
            ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: body,
      ),
    );
  }
}

class _CatalogBookTile extends StatelessWidget {
  const _CatalogBookTile({
    required this.book,
    required this.onTap,
  });

  final CatalogBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: colorScheme.surfaceContainerHighest,
                child: book.coverImageUrl != null &&
                        book.coverImageUrl!.isNotEmpty
                    ? Image.network(
                        book.coverImageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) =>
                            _PlaceholderCover(title: book.title),
                      )
                    : _PlaceholderCover(title: book.title),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            book.authorLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final background = Colors
        .primaries[title.hashCode.abs() % Colors.primaries.length]
        .shade200;

    return Container(
      width: double.infinity,
      color: background,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Text(
        title,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(L10n.of(context).commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isCatalogNotFoundError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('404') ||
      message.contains('not found') ||
      message.contains('no books') ||
      message.contains('no purchased') ||
      message.contains('no library') ||
      message.contains('failed to load books') ||
      message.contains('unauthorized') ||
      message.contains('authentication');
}
