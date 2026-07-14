class CatalogBook {
  const CatalogBook({
    required this.id,
    required this.title,
    required this.authors,
    this.coverImageUrl,
    this.description,
    this.publisher,
    this.pageCount,
    this.isFree = false,
    this.price,
    this.currency,
    this.isReview = false,
    this.entryId,
    this.bookFileUrl,
    this.encryptionKey,
    this.encryptionIv,
  });

  factory CatalogBook.fromPurchasedJson(Map<String, dynamic> json) {
    final book = _asMap(json['bookId']);
    return CatalogBook(
      entryId: json['_id']?.toString(),
      id: book['_id']?.toString() ?? json['bookId']?.toString() ?? '',
      title: book['title']?.toString() ?? 'Untitled',
      authors: _parseAuthors(book['author']),
      coverImageUrl: book['coverImageUrl']?.toString(),
      description: book['description']?.toString(),
      publisher: book['publisher']?.toString(),
      pageCount: _asInt(book['pageCount']),
      isFree: book['isFree'] == true,
      price: _asDouble(book['price']),
      currency: book['currency']?.toString(),
      isReview: json['isReview'] == true,
      bookFileUrl: book['bookFileUrl']?.toString(),
      // API stores user-wrapped key/iv as `key` / `iv`
      encryptionKey: json['key']?.toString(),
      encryptionIv: json['iv']?.toString(),
    );
  }

  final String id;
  final String? entryId;
  final String title;
  final List<String> authors;
  final String? coverImageUrl;
  final String? description;
  final String? publisher;
  final int? pageCount;
  final bool isFree;
  final double? price;
  final String? currency;
  final bool isReview;
  final String? bookFileUrl;

  /// Hex: IV(16) || AES-CBC(book encryption key), wrapped with user key.
  final String? encryptionKey;

  /// Hex: IV(16) || AES-CBC(book IV), wrapped with user key.
  final String? encryptionIv;

  String get authorLabel =>
      authors.isEmpty ? 'Unknown author' : authors.join(', ');

  bool get canDecrypt =>
      bookFileUrl != null &&
      bookFileUrl!.isNotEmpty &&
      encryptionKey != null &&
      encryptionKey!.isNotEmpty &&
      encryptionIv != null &&
      encryptionIv!.isNotEmpty;

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static List<String> _parseAuthors(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    if (value is String && value.isNotEmpty) return [value];
    return const [];
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class CatalogBookPage {
  const CatalogBookPage({
    required this.books,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
    required this.limit,
  });

  final List<CatalogBook> books;
  final int currentPage;
  final int totalPages;
  final int totalRecords;
  final int limit;

  bool get hasMore => currentPage < totalPages;
}
