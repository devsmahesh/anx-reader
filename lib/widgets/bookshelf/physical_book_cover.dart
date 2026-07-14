import 'dart:io';
import 'dart:math' as math;

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A cover that reads like a physical book: depth shadow, spine, page edge.
class PhysicalBookCover extends StatelessWidget {
  const PhysicalBookCover({
    super.key,
    required this.child,
    this.radius = 6,
    this.showShadow = true,
  });

  final Widget child;
  final double radius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final eInk = Prefs().eInkMode;
    final borderRadius = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: (!showShadow || eInk)
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                  offset: const Offset(3, 5),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 3,
                  offset: const Offset(1, 1),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            // Spine: darker strip + crease on the left edge
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 10,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: eInk ? 0.35 : 0.28),
                        Colors.black.withValues(alpha: eInk ? 0.12 : 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Thin highlight next to the spine (binding crease)
            Positioned(
              left: 7,
              top: 0,
              bottom: 0,
              width: 1.2,
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: eInk ? 0.15 : 0.22),
                ),
              ),
            ),
            // Page edge on the right
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: eInk ? 0.2 : 0.35),
                        const Color(0xFFF5F0E6).withValues(alpha: 0.9),
                      ],
                      stops: const [0.0, 0.35, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Soft top sheen
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 28,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: eInk ? 0.06 : 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Network / placeholder cover used by purchased & library catalogs.
class CatalogBookCoverArt extends StatelessWidget {
  const CatalogBookCoverArt({
    super.key,
    required this.title,
    this.author,
    this.coverImageUrl,
  });

  final String title;
  final String? author;
  final String? coverImageUrl;

  @override
  Widget build(BuildContext context) {
    final hasUrl = coverImageUrl != null && coverImageUrl!.isNotEmpty;

    return PhysicalBookCover(
      child: hasUrl
          ? CachedNetworkImage(
              imageUrl: coverImageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder: (_, __) => GeneratedBookCover(
                title: title,
                author: author,
              ),
              errorWidget: (_, __, ___) => GeneratedBookCover(
                title: title,
                author: author,
              ),
            )
          : GeneratedBookCover(
              title: title,
              author: author,
            ),
    );
  }
}

/// Book-shaped fallback when no cover art is available.
class GeneratedBookCover extends StatelessWidget {
  const GeneratedBookCover({
    super.key,
    required this.title,
    this.author,
    this.showTitle,
    this.showAuthor,
  });

  final String title;
  final String? author;
  final bool? showTitle;
  final bool? showAuthor;

  Color _baseColor() {
    final palette = <Color>[
      const Color(0xFF8B6B5A),
      const Color(0xFF5C6B73),
      const Color(0xFF6B5B7A),
      const Color(0xFF5A6B5C),
      const Color(0xFF7A5A5A),
      const Color(0xFF4A5A6B),
      const Color(0xFF6B5C4A),
      const Color(0xFF5A556B),
    ];
    return palette[title.hashCode.abs() % palette.length];
  }

  Color _contrastOn(Color background) {
    final brightness = ThemeData.estimateBrightnessForColor(background);
    return brightness == Brightness.dark ? Colors.white : Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    final base = _baseColor();
    final textColor = _contrastOn(base);
    final displayTitle = showTitle ?? Prefs().showBookTitleOnDefaultCover;
    final displayAuthor = showAuthor ?? Prefs().showAuthorOnDefaultCover;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 120.0;
        final titleSize = (w * 0.11).clamp(11.0, 16.0);
        final authorSize = (w * 0.075).clamp(9.0, 12.0);
        final pad = (w * 0.1).clamp(8.0, 14.0);

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(base, Colors.white, 0.12)!,
                base,
                Color.lerp(base, Colors.black, 0.18)!,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Soft paper texture bands
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CoverTexturePainter(
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                ),
              ),
              // Decorative band across mid-cover
              Positioned(
                left: 0,
                right: 0,
                top: constraints.maxHeight.isFinite
                    ? constraints.maxHeight * 0.32
                    : 48,
                height: 3,
                child: ColoredBox(
                  color: textColor.withValues(alpha: 0.18),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(pad + 4, pad, pad, pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (displayTitle)
                      Text(
                        title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: textColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    const Spacer(),
                    if (displayAuthor &&
                        author != null &&
                        author!.trim().isNotEmpty)
                      Text(
                        author!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: authorSize,
                          fontWeight: FontWeight.w400,
                          color: textColor.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: -pad * 0.4,
                bottom: -pad * 0.3,
                child: Transform.rotate(
                  angle: 12 * math.pi / 180,
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: w * 0.55,
                    color: textColor.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Local-file cover face used by the bookshelf [BookCover].
class LocalBookCoverFace extends StatelessWidget {
  const LocalBookCoverFace({
    super.key,
    required this.file,
    required this.title,
    required this.author,
  });

  final File file;
  final String title;
  final String author;

  @override
  Widget build(BuildContext context) {
    if (file.existsSync()) {
      return DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: FileImage(file),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return GeneratedBookCover(
      title: title,
      author: author,
    );
  }
}

class _CoverTexturePainter extends CustomPainter {
  _CoverTexturePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const step = 7.0;
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoverTexturePainter oldDelegate) =>
      oldDelegate.color != color;
}
