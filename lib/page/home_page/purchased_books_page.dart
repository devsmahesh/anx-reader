import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/page/home_page/catalog_books_page.dart';
import 'package:anx_reader/providers/catalog_books.dart';
import 'package:flutter/material.dart';

class PurchasedBooksPage extends StatelessWidget {
  const PurchasedBooksPage({super.key, this.controller});

  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return CatalogBooksPage(
      provider: purchasedBooksProvider,
      controller: controller,
      emptyMessage: L10n.of(context).catalogNoPurchasedBooks,
    );
  }
}
