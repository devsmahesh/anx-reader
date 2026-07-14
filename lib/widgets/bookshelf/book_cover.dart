import 'dart:io';

import 'package:anx_reader/models/book.dart';
import 'package:anx_reader/widgets/bookshelf/physical_book_cover.dart';
import 'package:flutter/material.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    this.height,
    this.width,
    this.radius,
  });

  final Book book;
  final double? height;
  final double? width;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final double effectiveRadius = radius ?? 6;
    final File file = File(book.coverFullPath);

    return SizedBox(
      height: height,
      width: width,
      child: PhysicalBookCover(
        radius: effectiveRadius,
        child: LocalBookCoverFace(
          file: file,
          title: book.title,
          author: book.author,
        ),
      ),
    );
  }
}
