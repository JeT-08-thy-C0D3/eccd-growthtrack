/// Repository Base Class with Pagination
/// 
/// Provides a template for all entity repositories with built-in pagination,
/// filtering, and sorting support.
/// 
/// Usage:
///   class EvaluationRepository extends RepositoryBase<EvaluationSession> {
///     @override
///     String get collectionName => 'evaluation_sessions';
///     @override
///     EvaluationSession fromJson(Map<String, dynamic> json) => EvaluationSession.fromJson(json);
///   }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'query_builder.dart';
import 'pagination_service.dart';

abstract class RepositoryBase<T> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PaginationService _paginationService = PaginationService();

  /// Collection name in Firestore
  String get collectionName;

  /// Convert JSON to entity
  T fromJson(Map<String, dynamic> json);

  /// Convert entity to JSON
  Map<String, dynamic> toJson(T entity);

  /// Get collection reference
  CollectionReference get collection => _firestore.collection(collectionName);

  // ============================================================================
  // CREATE
  // ============================================================================

  /// Create new entity
  Future<String> create(T entity) async {
    try {
      final doc = await collection.add(toJson(entity));
      return doc.id;
    } catch (e) {
      print('Error creating $T: $e');
      rethrow;
    }
  }

  /// Create with custom ID
  Future<void> createWithId(String id, T entity) async {
    try {
      await collection.doc(id).set(toJson(entity));
    } catch (e) {
      print('Error creating $T with id $id: $e');
      rethrow;
    }
  }

  // ============================================================================
  // READ
  // ============================================================================

  /// Get single entity by ID
  Future<T?> getById(String id) async {
    try {
      final doc = await collection.doc(id).get();
      if (!doc.exists) return null;

      return fromJson({
        ...doc.data() as Map<String, dynamic>,
        '__id': doc.id,
      });
    } catch (e) {
      print('Error getting $T by id: $e');
      return null;
    }
  }

  /// Get multiple entities by IDs
  Future<List<T>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    try {
      final chunks = <List<String>>[];
      for (int i = 0; i < ids.length; i += 10) {
        chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
      }

      final results = <T>[];
      for (final chunk in chunks) {
        final snapshot = await collection
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snapshot.docs) {
          results.add(fromJson({
            ...doc.data() as Map<String, dynamic>,
            '__id': doc.id,
          }));
        }
      }

      return results;
    } catch (e) {
      print('Error getting $T by ids: $e');
      return [];
    }
  }

  /// Get all entities (WARNING: expensive for large collections)
  Future<List<T>> getAll({int limit = 10000}) async {
    try {
      final snapshot = await collection.limit(limit).get();
      return snapshot.docs
          .map((doc) => fromJson({
                ...doc.data() as Map<String, dynamic>,
                '__id': doc.id,
              }))
          .toList();
    } catch (e) {
      print('Error getting all $T: $e');
      return [];
    }
  }

  // ============================================================================
  // UPDATE
  // ============================================================================

  /// Update entity
  Future<void> update(String id, T entity) async {
    try {
      await collection.doc(id).update(toJson(entity));
    } catch (e) {
      print('Error updating $T: $e');
      rethrow;
    }
  }

  /// Partial update (only specified fields)
  Future<void> updatePartial(String id, Map<String, dynamic> updates) async {
    try {
      await collection.doc(id).update(updates);
    } catch (e) {
      print('Error partially updating $T: $e');
      rethrow;
    }
  }

  // ============================================================================
  // DELETE
  // ============================================================================

  /// Delete entity (hard delete)
  Future<void> delete(String id) async {
    try {
      await collection.doc(id).delete();
    } catch (e) {
      print('Error deleting $T: $e');
      rethrow;
    }
  }

  /// Soft delete (mark as deleted)
  Future<void> softDelete(String id) async {
    try {
      await collection.doc(id).update({
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error soft deleting $T: $e');
      rethrow;
    }
  }

  /// Delete batch of entities
  Future<void> deleteBatch(List<String> ids) async {
    try {
      final batch = _firestore.batch();
      for (final id in ids) {
        batch.delete(collection.doc(id));
      }
      await batch.commit();
    } catch (e) {
      print('Error batch deleting $T: $e');
      rethrow;
    }
  }

  // ============================================================================
  // QUERY & PAGINATION
  // ============================================================================

  /// Query with filters, sorting, and pagination
  Future<PaginatedResult<T>> query(
    QueryBuilder queryBuilder, {
    String? cursorValue,
    int pageNumber = 1,
  }) async {
    try {
      var firestoreQuery = collection as Query;
      firestoreQuery = queryBuilder.applyToFirestoreQuery(firestoreQuery);

      return await _paginationService.paginate(
        firestoreQuery,
        fromJson: (json) => fromJson({...json, '__id': json['__id'] ?? ''}),
        cursorValue: cursorValue,
        pageSize: queryBuilder.pageSize,
        pageNumber: pageNumber,
      );
    } catch (e) {
      print('Error querying $T: $e');
      rethrow;
    }
  }

  /// Get first page with filters and sorting
  Future<PaginatedResult<T>> getFirstPage({
    QueryBuilder? queryBuilder,
    int pageSize = 10,
  }) async {
    try {
      queryBuilder ??= QueryBuilder(collectionName: collectionName);
      queryBuilder.limit(pageSize);

      var firestoreQuery = collection as Query;
      firestoreQuery = queryBuilder.applyToFirestoreQuery(firestoreQuery);

      return await _paginationService.getFirstPage(
        firestoreQuery,
        fromJson: (json) => fromJson({...json, '__id': json['__id'] ?? ''}),
        pageSize: pageSize,
      );
    } catch (e) {
      print('Error getting first page of $T: $e');
      rethrow;
    }
  }

  /// Get next page
  Future<PaginatedResult<T>> getNextPage({
    required PaginationCursor cursor,
    QueryBuilder? queryBuilder,
    int pageSize = 10,
  }) async {
    try {
      queryBuilder ??= QueryBuilder(collectionName: collectionName);
      queryBuilder.limit(pageSize);

      var firestoreQuery = collection as Query;
      firestoreQuery = queryBuilder.applyToFirestoreQuery(firestoreQuery);

      return await _paginationService.getNextPage(
        firestoreQuery,
        fromJson: (json) => fromJson({...json, '__id': json['__id'] ?? ''}),
        cursor: cursor,
        pageSize: pageSize,
      );
    } catch (e) {
      print('Error getting next page of $T: $e');
      rethrow;
    }
  }

  // ============================================================================
  // UTILITIES
  // ============================================================================

  /// Count entities (exact count)
  Future<int> count() async {
    try {
      return await _paginationService.getExactCount(collection as Query);
    } catch (e) {
      print('Error counting $T: $e');
      return 0;
    }
  }

  /// Count with filters
  Future<int> countWhere(QueryBuilder queryBuilder) async {
    try {
      var firestoreQuery = collection as Query;
      firestoreQuery = queryBuilder.applyToFirestoreQuery(firestoreQuery);

      return await _paginationService.getExactCount(firestoreQuery);
    } catch (e) {
      print('Error counting $T with filters: $e');
      return 0;
    }
  }

  /// Check if entity exists
  Future<bool> exists(String id) async {
    try {
      final doc = await collection.doc(id).get();
      return doc.exists;
    } catch (e) {
      print('Error checking existence of $T: $e');
      return false;
    }
  }

  /// Stream first page (for real-time updates)
  Stream<PaginatedResult<T>> streamFirstPage({
    QueryBuilder? queryBuilder,
    int pageSize = 10,
  }) {
    queryBuilder ??= QueryBuilder(collectionName: collectionName);
    queryBuilder.limit(pageSize);

    var firestoreQuery = collection as Query;
    firestoreQuery = queryBuilder.applyToFirestoreQuery(firestoreQuery);

    return firestoreQuery.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => fromJson({
                ...doc.data() as Map<String, dynamic>,
                '__id': doc.id,
              }))
          .toList();

      return PaginatedResult(
        items: items,
        pageNumber: 1,
      );
    });
  }

  /// Stream with filters
  Stream<List<T>> streamWhere(QueryBuilder queryBuilder) {
    var firestoreQuery = collection as Query;
    firestoreQuery = queryBuilder.applyToFirestoreQuery(firestoreQuery);

    return firestoreQuery.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => fromJson({
                ...doc.data() as Map<String, dynamic>,
                '__id': doc.id,
              }))
          .toList();
    });
  }
}
