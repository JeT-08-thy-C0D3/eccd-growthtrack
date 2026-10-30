/// Query Builder and Filtering Abstraction
/// 
/// Unified query system supporting:
/// - Text search
/// - Filters (date range, status, user type, domain, etc.)
/// - Sorting (field + direction)
/// - Cursor-based pagination
/// - Applied to all entity types (users, children, evaluations, referrals, etc.)
library;

import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================================
// FILTERS
// ============================================================================

/// Base class for all filter types
abstract class QueryFilter {
  Map<String, dynamic> toJson();
}

/// Text search filter
class TextSearchFilter extends QueryFilter {
  final String searchText;
  final List<String> searchFields; // Fields to search in

  TextSearchFilter({
    required this.searchText,
    this.searchFields = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'text_search',
    'searchText': searchText,
    'searchFields': searchFields,
  };
}

/// Status filter (e.g., 'active', 'pending', 'completed', 'archived')
class StatusFilter extends QueryFilter {
  final List<String> statuses;
  final String fieldName;

  StatusFilter({
    required this.statuses,
    this.fieldName = 'status',
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'status',
    'statuses': statuses,
    'fieldName': fieldName,
  };
}

/// Date range filter
class DateRangeFilter extends QueryFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String fieldName;

  DateRangeFilter({
    this.startDate,
    this.endDate,
    required this.fieldName,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'date_range',
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'fieldName': fieldName,
  };
}

/// Timestamp range filter (for evaluations, assessments)
class TimestampRangeFilter extends QueryFilter {
  final DateTime? startTime;
  final DateTime? endTime;
  final String fieldName;

  TimestampRangeFilter({
    this.startTime,
    this.endTime,
    required this.fieldName,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'timestamp_range',
    'startTime': startTime?.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'fieldName': fieldName,
  };
}

/// Single value equality filter
class EqualityFilter extends QueryFilter {
  final String fieldName;
  final dynamic value;

  EqualityFilter({
    required this.fieldName,
    required this.value,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'equality',
    'fieldName': fieldName,
    'value': value,
  };
}

/// Multi-value equality filter (OR logic)
class InFilter extends QueryFilter {
  final String fieldName;
  final List<dynamic> values;

  InFilter({
    required this.fieldName,
    required this.values,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'in',
    'fieldName': fieldName,
    'values': values,
  };
}

/// User type filter (admin, teacher, parent)
class UserTypeFilter extends QueryFilter {
  final List<String> userTypes;

  UserTypeFilter({required this.userTypes});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'user_type',
    'userTypes': userTypes,
  };
}

/// Child filter (for evaluation/referral/activity queries)
class ChildFilter extends QueryFilter {
  final String childId;

  ChildFilter({required this.childId});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'child',
    'childId': childId,
  };
}

/// Domain filter (for evaluations - gross motor, fine motor, etc.)
class DomainFilter extends QueryFilter {
  final String domain;

  DomainFilter({required this.domain});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'domain',
    'domain': domain,
  };
}

/// Center filter (for multi-center systems)
class CenterFilter extends QueryFilter {
  final String centerId;

  CenterFilter({required this.centerId});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'center',
    'centerId': centerId,
  };
}

// ============================================================================
// SORTING
// ============================================================================

enum SortDirection { ascending, descending }

class SortOrder {
  final String fieldName;
  final SortDirection direction;

  SortOrder({
    required this.fieldName,
    this.direction = SortDirection.descending,
  });

  Map<String, dynamic> toJson() => {
    'fieldName': fieldName,
    'direction': direction.name,
  };
}

// ============================================================================
// QUERY BUILDER
// ============================================================================

class QueryBuilder {
  final String collectionName;
  final List<QueryFilter> _filters = [];
  SortOrder? _sortOrder;
  int _pageSize = 10;
  String? _startAfterCursor;
  bool _includeStartAfter = false;

  QueryBuilder({required this.collectionName});

  /// Add a filter
  QueryBuilder filter(QueryFilter filter) {
    _filters.add(filter);
    return this;
  }

  /// Text search
  QueryBuilder search(String text, {List<String> fields = const []}) {
    _filters.add(TextSearchFilter(
      searchText: text,
      searchFields: fields,
    ));
    return this;
  }

  /// Filter by status
  QueryBuilder whereStatus(List<String> statuses, {String fieldName = 'status'}) {
    _filters.add(StatusFilter(
      statuses: statuses,
      fieldName: fieldName,
    ));
    return this;
  }

  /// Filter by date range
  QueryBuilder whereDateBetween(
    DateTime? start,
    DateTime? end, {
    required String fieldName,
  }) {
    _filters.add(DateRangeFilter(
      startDate: start,
      endDate: end,
      fieldName: fieldName,
    ));
    return this;
  }

  /// Filter by timestamp range
  QueryBuilder whereTimestampBetween(
    DateTime? start,
    DateTime? end, {
    required String fieldName,
  }) {
    _filters.add(TimestampRangeFilter(
      startTime: start,
      endTime: end,
      fieldName: fieldName,
    ));
    return this;
  }

  /// Filter by equality
  QueryBuilder where(String fieldName, dynamic value) {
    _filters.add(EqualityFilter(
      fieldName: fieldName,
      value: value,
    ));
    return this;
  }

  /// Filter by value in list
  QueryBuilder whereIn(String fieldName, List<dynamic> values) {
    _filters.add(InFilter(
      fieldName: fieldName,
      values: values,
    ));
    return this;
  }

  /// Filter by user type
  QueryBuilder whereUserType(List<String> userTypes) {
    _filters.add(UserTypeFilter(userTypes: userTypes));
    return this;
  }

  /// Filter by child
  QueryBuilder whereChild(String childId) {
    _filters.add(ChildFilter(childId: childId));
    return this;
  }

  /// Filter by domain
  QueryBuilder whereDomain(String domain) {
    _filters.add(DomainFilter(domain: domain));
    return this;
  }

  /// Filter by center
  QueryBuilder whereCenter(String centerId) {
    _filters.add(CenterFilter(centerId: centerId));
    return this;
  }

  /// Set sort order
  QueryBuilder orderBy(String fieldName, {SortDirection direction = SortDirection.descending}) {
    _sortOrder = SortOrder(
      fieldName: fieldName,
      direction: direction,
    );
    return this;
  }

  /// Set page size
  QueryBuilder limit(int pageSize) {
    _pageSize = pageSize;
    return this;
  }

  /// Set cursor for pagination
  QueryBuilder startAfter(String cursor, {bool includeStartAfter = false}) {
    _startAfterCursor = cursor;
    _includeStartAfter = includeStartAfter;
    return this;
  }

  // Getters for building queries
  List<QueryFilter> get filters => List.unmodifiable(_filters);
  SortOrder? get sortOrder => _sortOrder;
  int get pageSize => _pageSize;
  String? get startAfterCursor => _startAfterCursor;
  bool get includeStartAfter => _includeStartAfter;

  /// Build to JSON for transport
  Map<String, dynamic> toJson() => {
    'collection': collectionName,
    'filters': _filters.map((f) => f.toJson()).toList(),
    'sortOrder': _sortOrder?.toJson(),
    'pageSize': _pageSize,
    'cursor': _startAfterCursor,
    'includeStartAfter': _includeStartAfter,
  };

  /// Apply to Firestore query
  Query applyToFirestoreQuery(Query query) {
    // Apply filters
    for (final filter in _filters) {
      query = _applyFilter(query, filter);
    }

    // Apply sort
    if (_sortOrder != null) {
      query = query.orderBy(
        _sortOrder!.fieldName,
        descending: _sortOrder!.direction == SortDirection.descending,
      );
    }

    // Apply pagination
    if (_startAfterCursor != null) {
      // TODO: Implement cursor-based pagination
      // For now, use document ID as cursor
      if (_includeStartAfter) {
        query = query.startAt([_startAfterCursor]);
      } else {
        query = query.startAfter([_startAfterCursor]);
      }
    }

    // Apply limit
    query = query.limit(_pageSize);

    return query;
  }

  /// Apply single filter to Firestore query
  Query _applyFilter(Query query, QueryFilter filter) {
    if (filter is TextSearchFilter) {
      // Text search not directly supported in Firestore
      // Should be implemented at application level or via external search
      return query;
    } else if (filter is StatusFilter) {
      return query.where(filter.fieldName, whereIn: filter.statuses);
    } else if (filter is DateRangeFilter) {
      if (filter.startDate != null) {
        query = query.where(
          filter.fieldName,
          isGreaterThanOrEqualTo: filter.startDate!,
        );
      }
      if (filter.endDate != null) {
        query = query.where(
          filter.fieldName,
          isLessThanOrEqualTo: filter.endDate!,
        );
      }
      return query;
    } else if (filter is TimestampRangeFilter) {
      if (filter.startTime != null) {
        query = query.where(
          filter.fieldName,
          isGreaterThanOrEqualTo: filter.startTime!,
        );
      }
      if (filter.endTime != null) {
        query = query.where(
          filter.fieldName,
          isLessThanOrEqualTo: filter.endTime!,
        );
      }
      return query;
    } else if (filter is EqualityFilter) {
      return query.where(filter.fieldName, isEqualTo: filter.value);
    } else if (filter is InFilter) {
      return query.where(filter.fieldName, whereIn: filter.values);
    } else if (filter is UserTypeFilter) {
      return query.where('userType', whereIn: filter.userTypes);
    } else if (filter is ChildFilter) {
      return query.where('childId', isEqualTo: filter.childId);
    } else if (filter is DomainFilter) {
      return query.where('domain', isEqualTo: filter.domain);
    } else if (filter is CenterFilter) {
      return query.where('centerId', isEqualTo: filter.centerId);
    }

    return query;
  }
}
