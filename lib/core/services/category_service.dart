/// Category Service with Caching
/// 
/// Manages category administration and provides efficient access to categories.
/// Supports create, read, update, delete, and caching with TTL.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/canonical/category_model.dart';

class CategoryService {
  static final CategoryService _instance = CategoryService._init();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache: categoryType -> List<Category>
  final Map<String, List<Category>> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheTTL = Duration(hours: 1);

  CategoryService._init();

  factory CategoryService() => _instance;

  /// Get all categories of a type (with caching)
  Future<List<Category>> getCategoriesByType(String categoryType) async {
    // Check cache
    if (_cache.containsKey(categoryType)) {
      final timestamp = _cacheTimestamps[categoryType];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheTTL) {
        print('✓ Returning cached categories for $categoryType');
        return _cache[categoryType]!;
      }
    }

    try {
      // Fetch from Firestore
      final snapshot = await _firestore
          .collection('categories')
          .where('categoryType', isEqualTo: categoryType)
          .where('isActive', isEqualTo: true)
          .orderBy('displayOrder')
          .orderBy('name')
          .get();

      final categories = snapshot.docs
          .map((doc) => Category.fromJson({
                ...doc.data(),
                'id': doc.id,
              }))
          .toList();

      // Update cache
      _cache[categoryType] = categories;
      _cacheTimestamps[categoryType] = DateTime.now();

      print('✓ Loaded ${categories.length} categories for $categoryType');
      return categories;
    } catch (e) {
      print('Error loading categories: $e');
      return [];
    }
  }

  /// Get single category by ID
  Future<Category?> getCategoryById(String id) async {
    try {
      final doc = await _firestore.collection('categories').doc(id).get();
      if (!doc.exists) return null;

      return Category.fromJson({
        ...doc.data() as Map<String, dynamic>,
        'id': doc.id,
      });
    } catch (e) {
      print('Error getting category: $e');
      return null;
    }
  }

  /// Create new category (admin only)
  Future<String> createCategory({
    required String name,
    required String description,
    required String categoryType,
    int displayOrder = 0,
    Map<String, dynamic>? metadata,
    String? createdBy,
  }) async {
    try {
      final doc = await _firestore.collection('categories').add({
        'name': name,
        'description': description,
        'categoryType': categoryType,
        'displayOrder': displayOrder,
        'isActive': true,
        'metadata': metadata,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
      });

      // Invalidate cache
      _cache.remove(categoryType);

      print('✓ Created category: $name');
      return doc.id;
    } catch (e) {
      print('Error creating category: $e');
      rethrow;
    }
  }

  /// Update category (admin only)
  Future<void> updateCategory(
    String id, {
    String? name,
    String? description,
    int? displayOrder,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (displayOrder != null) updates['displayOrder'] = displayOrder;
      if (isActive != null) updates['isActive'] = isActive;
      if (metadata != null) updates['metadata'] = metadata;

      await _firestore.collection('categories').doc(id).update(updates);

      // Invalidate all caches (we don't know which type this is)
      _cache.clear();

      print('✓ Updated category: $id');
    } catch (e) {
      print('Error updating category: $e');
      rethrow;
    }
  }

  /// Delete category (soft delete)
  Future<void> deleteCategory(String id) async {
    try {
      await _firestore.collection('categories').doc(id).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Invalidate cache
      _cache.clear();

      print('✓ Deleted category: $id');
    } catch (e) {
      print('Error deleting category: $e');
      rethrow;
    }
  }

  /// Reorder categories
  Future<void> reorderCategories(
    String categoryType,
    List<String> orderedIds,
  ) async {
    try {
      final batch = _firestore.batch();

      for (int i = 0; i < orderedIds.length; i++) {
        batch.update(
          _firestore.collection('categories').doc(orderedIds[i]),
          {'displayOrder': i},
        );
      }

      await batch.commit();

      // Invalidate cache
      _cache.remove(categoryType);

      print('✓ Reordered categories for $categoryType');
    } catch (e) {
      print('Error reordering categories: $e');
      rethrow;
    }
  }

  /// Initialize categories (create defaults if not exist)
  Future<void> initializeDefaultCategories() async {
    try {
      print('Checking for default categories...');

      // Get all category counts
      final existingCounts = <String, int>{};
      for (final type in CategoryType.allTypes) {
        final count = await _firestore
            .collection('categories')
            .where('categoryType', isEqualTo: type)
            .count()
            .get()
            .then((count) => count.count ?? 0);

        existingCounts[type] = count;
      }

      // Create missing defaults
      final batch = _firestore.batch();

      if (existingCounts[CategoryType.referralConcern] == 0) {
        for (final concern in DefaultCategories.referralConcerns) {
          batch.set(
            _firestore.collection('categories').doc(),
            {
              ...concern,
              'isActive': true,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        }
      }

      if (existingCounts[CategoryType.referralAgency] == 0) {
        for (final agency in DefaultCategories.referralAgencies) {
          batch.set(
            _firestore.collection('categories').doc(),
            {
              ...agency,
              'isActive': true,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        }
      }

      if (existingCounts[CategoryType.activityType] == 0) {
        for (final activity in DefaultCategories.activityTypes) {
          batch.set(
            _firestore.collection('categories').doc(),
            {
              ...activity,
              'isActive': true,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        }
      }

      if (existingCounts[CategoryType.notificationType] == 0) {
        for (final notification in DefaultCategories.notificationTypes) {
          batch.set(
            _firestore.collection('categories').doc(),
            {
              ...notification,
              'isActive': true,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        }
      }

      if (existingCounts[CategoryType.interventionType] == 0) {
        for (final intervention in DefaultCategories.interventionTypes) {
          batch.set(
            _firestore.collection('categories').doc(),
            {
              ...intervention,
              'isActive': true,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        }
      }

      if (existingCounts[CategoryType.accommodationType] == 0) {
        for (final accommodation in DefaultCategories.accommodationTypes) {
          batch.set(
            _firestore.collection('categories').doc(),
            {
              ...accommodation,
              'isActive': true,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        }
      }

      await batch.commit();

      print('✓ Default categories initialized');
    } catch (e) {
      print('Error initializing default categories: $e');
    }
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
    print('✓ Category cache cleared');
  }

  /// Get categories as dropdown options
  Future<List<DropdownOption>> getCategoryOptions(
    String categoryType,
  ) async {
    final categories = await getCategoriesByType(categoryType);
    return categories
        .map((cat) => DropdownOption(
              value: cat.id,
              label: cat.name,
              description: cat.description,
            ))
        .toList();
  }

  /// Stream categories for real-time updates
  Stream<List<Category>> streamCategoriesByType(String categoryType) {
    return _firestore
        .collection('categories')
        .where('categoryType', isEqualTo: categoryType)
        .where('isActive', isEqualTo: true)
        .orderBy('displayOrder')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Category.fromJson({
                ...doc.data(),
                'id': doc.id,
              }))
          .toList();
    });
  }
}

// ============================================================================
// DROPDOWN OPTION MODEL
// ============================================================================

class DropdownOption {
  final String value;
  final String label;
  final String? description;
  final bool isSelected;

  DropdownOption({
    required this.value,
    required this.label,
    this.description,
    this.isSelected = false,
  });
}
