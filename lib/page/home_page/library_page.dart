import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/page/home_page/catalog_books_page.dart';
import 'package:anx_reader/providers/catalog_books.dart';
import 'package:flutter/material.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, this.controller});

  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return CatalogBooksPage(
      provider: libraryBooksProvider,
      controller: controller,
      emptyMessage: L10n.of(context).catalogNoLibraryBooks,
    );
  }
}
