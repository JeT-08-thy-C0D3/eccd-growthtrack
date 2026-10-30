/// Pagination Service with Cursor Support
///
/// Implements cursor-based pagination for efficient loading of large datasets.
/// Provides page-by-page navigation without loading entire collection.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================================
// PAGINATION CURSOR
// ============================================================================

class PaginationCursor {
  /// Encoded cursor value (typically a document ID or timestamp)
  final String value;

  /// Timestamp when cursor was created
  final DateTime createdAt;

  /// Page number this cursor represents
  final int pageNumber;

  /// Whether to include the cursor document or start after it
  final bool inclusive;

  PaginationCursor({
    required this.value,
    required this.pageNumber,
    DateTime? createdAt,
    this.inclusive = false,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Encode cursor to string
  String encode() {
    return 'p$pageNumber:$value:${inclusive ? '1' : '0'}';
  }

  /// Decode cursor from string
  static PaginationCursor? decode(String encoded) {
    try {
      final parts = encoded.split(':');
      if (parts.length != 3) return null;

      final pageNum = int.parse(parts[0].substring(1));
      final cursorValue = parts[1];
      final isInclusive = parts[2] == '1';

      return PaginationCursor(
        value: cursorValue,
        pageNumber: pageNum,
        inclusive: isInclusive,
      );
    } catch (e) {
      print('Failed to decode cursor: $e');
      return null;
    }
  }

  @override
  String toString() => encode();
}

// ============================================================================
// PAGINATED RESULT
// ============================================================================

class PaginatedResult<T> {
  /// List of items on this page
  final List<T> items;

  /// Cursor to fetch next page
  final PaginationCursor? nextCursor;

  /// Cursor to fetch previous page
  final PaginationCursor? previousCursor;

  /// Total number of items (if available)
  final int? totalCount;

  /// Current page number
  final int pageNumber;

  /// Total pages (if known)
  final int? totalPages;

  /// Whether there are more pages
  bool get hasNextPage => nextCursor != null;

  /// Whether there are previous pages
  bool get hasPreviousPage => previousCursor != null;

  /// Whether this is the first page
  bool get isFirstPage => pageNumber == 1;

  /// Whether this is the last page
  bool get isLastPage => !hasNextPage;

  PaginatedResult({
    required this.items,
    this.nextCursor,
    this.previousCursor,
    this.totalCount,
    this.pageNumber = 1,
    this.totalPages,
  });

  /// Create empty result
  factory PaginatedResult.empty() {
    return PaginatedResult(items: [], pageNumber: 1);
  }

  Map<String, dynamic> toJson() => {
    'items': items,
    'nextCursor': nextCursor?.encode(),
    'previousCursor': previousCursor?.encode(),
    'totalCount': totalCount,
    'pageNumber': pageNumber,
    'totalPages': totalPages,
    'hasNextPage': hasNextPage,
    'hasPreviousPage': hasPreviousPage,
  };
}

// ============================================================================
// PAGINATION SERVICE
// ============================================================================

class PaginationService {
  static final PaginationService _instance = PaginationService._init();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PaginationService._init();

  factory PaginationService() => _instance;

  /// Execute paginated query
  Future<PaginatedResult<T>> paginate<T>(
    Query query, {
    required T Function(Map<String, dynamic>) fromJson,
    String? cursorValue,
    int pageSize = 10,
    int pageNumber = 1,
  }) async {
    try {
      // Fetch pageSize + 1 to detect if there's a next page
      Query paginatedQuery = query.limit(pageSize + 1);

      // Apply cursor if provided
      if (cursorValue != null) {
        paginatedQuery = paginatedQuery.startAfter([cursorValue]);
      }

      final snapshot = await paginatedQuery.get();
      final docs = snapshot.docs;

      // Determine if there's a next page
      final hasNextPage = docs.length > pageSize;
      final itemDocs = hasNextPage ? docs.sublist(0, pageSize) : docs;

      // Convert to items
      final items = itemDocs
          .map(
            (doc) => fromJson({
              ...doc.data() as Map<String, dynamic>,
              '__id': doc.id,
            }),
          )
          .toList();

      // Generate cursors
      PaginationCursor? nextCursor;
      if (hasNextPage && itemDocs.isNotEmpty) {
        final lastDoc = itemDocs.last;
        nextCursor = PaginationCursor(
          value: lastDoc.id,
          pageNumber: pageNumber + 1,
          inclusive: false,
        );
      }

      // Previous cursor (simplified)
      PaginationCursor? previousCursor;
      if (pageNumber > 1 && itemDocs.isNotEmpty) {
        previousCursor = PaginationCursor(
          value: itemDocs.first.id,
          pageNumber: pageNumber - 1,
          inclusive: true,
        );
      }

      return PaginatedResult(
        items: items,
        nextCursor: nextCursor,
        previousCursor: previousCursor,
        pageNumber: pageNumber,
      );
    } catch (e) {
      print('Pagination error: $e');
      rethrow;
    }
  }

  /// Get page by cursor
  Future<PaginatedResult<T>> getPageByCursor<T>(
    Query query, {
    required T Function(Map<String, dynamic>) fromJson,
    required String cursor,
    int pageSize = 10,
  }) async {
    final decoded = PaginationCursor.decode(cursor);
    if (decoded == null) {
      throw Exception('Invalid cursor: $cursor');
    }

    return paginate(
      query,
      fromJson: fromJson,
      cursorValue: decoded.value,
      pageSize: pageSize,
      pageNumber: decoded.pageNumber,
    );
  }

  /// Get first page
  Future<PaginatedResult<T>> getFirstPage<T>(
    Query query, {
    required T Function(Map<String, dynamic>) fromJson,
    int pageSize = 10,
  }) async {
    return paginate(
      query,
      fromJson: fromJson,
      pageSize: pageSize,
      pageNumber: 1,
    );
  }

  /// Get next page
  Future<PaginatedResult<T>> getNextPage<T>(
    Query query, {
    required T Function(Map<String, dynamic>) fromJson,
    required PaginationCursor cursor,
    int pageSize = 10,
  }) async {
    return paginate(
      query,
      fromJson: fromJson,
      cursorValue: cursor.value,
      pageSize: pageSize,
      pageNumber: cursor.pageNumber,
    );
  }

  /// Get previous page
  Future<PaginatedResult<T>> getPreviousPage<T>(
    Query query, {
    required T Function(Map<String, dynamic>) fromJson,
    required PaginationCursor cursor,
    int pageSize = 10,
  }) async {
    // Previous pagination is complex; typically implemented as
    // fetching from start with all intermediate cursors
    throw UnimplementedError('Previous page requires full cursor history');
  }

  /// Load all pages (for small datasets)
  /// WARNING: Only use for collections with < 1000 items
  Future<List<T>> loadAll<T>(
    Query query, {
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    try {
      final snapshot = await query.get();
      return snapshot.docs
          .map(
            (doc) => fromJson({
              ...doc.data() as Map<String, dynamic>,
              '__id': doc.id,
            }),
          )
          .toList();
    } catch (e) {
      print('Error loading all: $e');
      rethrow;
    }
  }

  /// Estimate total count (uses smallest index)
  Future<int> estimateCount(Query query) async {
    try {
      // Firestore doesn't provide native count; approximate with limit
      final snapshot = await query.limit(10000).get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error estimating count: $e');
      return 0;
    }
  }

  /// Get exact count (expensive for large collections)
  Future<int> getExactCount(Query query) async {
    try {
      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting exact count: $e');
      return 0;
    }
  }
}
