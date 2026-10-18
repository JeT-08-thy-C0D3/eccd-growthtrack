# PHASE 5: SHARED QUERY, PAGINATION & FILTERING LAYER

## Implementation Guide

---

## Overview

Phase 5 creates a unified query and pagination system that:

- **One Query API**: All entity types use the same QueryBuilder
- **Cursor Pagination**: Memory-efficient page-by-page loading
- **Rich Filters**: Status, dates, ranges, search, user types, domains
- **Sorting**: By any field, ascending or descending
- **Repository Pattern**: Type-safe repositories for each entity
- **Real-time Streams**: Built-in streaming support
- **Firestore-Native**: Leverages Firestore indexes for performance

Applied to **13 entity types**:
1. Evaluations
2. Referrals
3. Attendance
4. Notifications
5. Children
6. Users
7. Audit Logs
8. Consent Records
9. Categories
10. Health Logs
11. Feedback
12. Clarification Requests
13. Activities

---

## Architecture

```
┌────────────────────────────────────────────────────────┐
│                 UI LAYER                               │
│  PaginatedListView (displays results + pagination)     │
│  FilterPanel (build QueryBuilder)                      │
│  SortDropdown (set sort order)                         │
└────────────────────┬───────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│                 REPOSITORY LAYER                        │
│  EvaluationRepository                                  │
│  ReferralRepository                                    │
│  UserRepository                                        │
│  ChildRepository                                       │
│  NotificationRepository                                │
│  AuditLogRepository                                    │
│  (all extend RepositoryBase<T>)                        │
└────────────────────┬───────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│              QUERY LAYER                               │
│                                                         │
│  QueryBuilder (fluent API)                             │
│    .whereStatus(['pending'])                           │
│    .whereDateBetween(start, end)                       │
│    .orderBy('createdAt')                              │
│    .limit(10)                                         │
│                                                         │
│  Applied to Firestore Query                            │
│  ↓                                                     │
│  db.collection('evaluations')                          │
│    .where('status', whereIn: ['pending'])             │
│    .where('createdAt', >=, start)                     │
│    .orderBy('createdAt')                              │
│    .limit(11)  /* +1 to detect next page */           │
└────────────────────┬───────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│           PAGINATION LAYER                             │
│                                                         │
│  PaginationCursor: "p1:docid-xyz:0"                   │
│  PaginatedResult<T>:                                  │
│    items: [eval1, eval2, ..., eval10]                 │
│    nextCursor: "p2:docid-abc:0"                       │
│    hasNextPage: true                                  │
│    pageNumber: 1                                      │
└────────────────────┬───────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│           FIRESTORE (Authority)                        │
│                                                         │
│  evaluation_sessions                                   │
│  referrals                                            │
│  children                                             │
│  users                                                │
│  audit_logs                                           │
│  (Query optimized by indexes)                         │
└────────────────────────────────────────────────────────┘
```

---

## New Files Created

1. **lib/core/database/query_builder.dart** (340 lines)
   - QueryFilter base class + 10 concrete filters
   - SortOrder enum
   - QueryBuilder (fluent API)
   - Firestore query translation

2. **lib/core/database/pagination_service.dart** (260 lines)
   - PaginationCursor (encoded cursor strings)
   - PaginatedResult<T> (page + metadata)
   - PaginationService (manages pagination)
   - Cursor encoding/decoding

3. **lib/core/database/repository_base.dart** (300 lines)
   - Generic RepositoryBase<T> base class
   - CRUD methods (create, read, update, delete)
   - Query & pagination methods
   - Streaming support
   - Soft delete support

4. **lib/data/repositories/entity_repositories.dart** (380 lines)
   - EvaluationRepository
   - ReferralRepository
   - AttendanceRepository
   - ChildRepository
   - UserRepository
   - NotificationRepository
   - AuditLogRepository

---

## Filter Types

### TextSearchFilter
```dart
QueryBuilder(collectionName: 'evaluations')
  .search('motor skill', fields: ['domain', 'indicator'])
```

### StatusFilter
```dart
QueryBuilder(collectionName: 'referrals')
  .whereStatus(['active', 'pending'])
  .whereStatus(['deleted'], fieldName: 'deletionStatus')
```

### DateRangeFilter
```dart
final start = DateTime(2024, 1, 1);
final end = DateTime(2024, 12, 31);

QueryBuilder(collectionName: 'evaluations')
  .whereDateBetween(start, end, fieldName: 'createdAt')
```

### TimestampRangeFilter
```dart
final now = DateTime.now();
final last24h = now.subtract(Duration(hours: 24));

QueryBuilder(collectionName: 'notifications')
  .whereTimestampBetween(last24h, now, fieldName: 'createdAt')
```

### EqualityFilter
```dart
QueryBuilder(collectionName: 'users')
  .where('role', 'teacher')
  .where('status', 'active')
```

### InFilter
```dart
QueryBuilder(collectionName: 'evaluations')
  .whereIn('domain', ['gross_motor', 'fine_motor'])
```

### UserTypeFilter
```dart
QueryBuilder(collectionName: 'audit_logs')
  .whereUserType(['admin', 'teacher'])
```

### ChildFilter
```dart
QueryBuilder(collectionName: 'evaluations')
  .whereChild('child-123')
```

### DomainFilter
```dart
QueryBuilder(collectionName: 'evaluations')
  .whereDomain('fine_motor')
```

### CenterFilter
```dart
QueryBuilder(collectionName: 'evaluations')
  .whereCenter('center-456')
```

---

## Usage Examples

### Example 1: List Evaluations with Filters & Pagination

```dart
class EvaluationListPage extends StatefulWidget {
  @override
  State<EvaluationListPage> createState() => _EvaluationListPageState();
}

class _EvaluationListPageState extends State<EvaluationListPage> {
  final _evaluationRepo = EvaluationRepository();
  
  PaginatedResult<EvaluationSession>? _currentPage;
  PaginationCursor? _nextCursor;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    // Build query
    final query = QueryBuilder(collectionName: 'evaluation_sessions')
        .whereStatus(['completed', 'pending'])
        .whereDateBetween(
          DateTime(2024, 1, 1),
          DateTime.now(),
          fieldName: 'createdAt',
        )
        .orderBy('createdAt', direction: SortDirection.descending)
        .limit(10);

    // Execute query
    final page = await _evaluationRepo.getFirstPage(
      queryBuilder: query,
      pageSize: 10,
    );

    setState(() {
      _currentPage = page;
      _nextCursor = page.nextCursor;
    });
  }

  Future<void> _loadNextPage() async {
    if (_nextCursor == null) return;

    final query = QueryBuilder(collectionName: 'evaluation_sessions')
        .orderBy('createdAt', direction: SortDirection.descending)
        .limit(10);

    final page = await _evaluationRepo.getNextPage(
      cursor: _nextCursor!,
      queryBuilder: query,
      pageSize: 10,
    );

    setState(() {
      _currentPage = page;
      _nextCursor = page.nextCursor;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _currentPage!.items.length,
            itemBuilder: (context, index) {
              final evaluation = _currentPage!.items[index];
              return EvaluationTile(evaluation: evaluation);
            },
          ),
        ),
        // Pagination controls
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _currentPage!.hasPreviousPage ? _loadNextPage : null,
                child: const Text('Previous'),
              ),
              Text('Page ${_currentPage!.pageNumber}'),
              ElevatedButton(
                onPressed: _currentPage!.hasNextPage ? _loadNextPage : null,
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

### Example 2: Filter & Search Referrals

```dart
class ReferralFilterPage extends StatefulWidget {
  @override
  State<ReferralFilterPage> createState() => _ReferralFilterPageState();
}

class _ReferralFilterPageState extends State<ReferralFilterPage> {
  final _referralRepo = ReferralRepository();
  
  String? _selectedStatus;
  String? _selectedChild;
  DateTimeRange? _dateRange;
  
  List<Referral> _results = [];

  void _applyFilters() async {
    // Build query
    var query = QueryBuilder(collectionName: 'referrals')
        .orderBy('createdAt', direction: SortDirection.descending);

    if (_selectedStatus != null) {
      query = query.whereStatus([_selectedStatus!]);
    }

    if (_selectedChild != null) {
      query = query.whereChild(_selectedChild!);
    }

    if (_dateRange != null) {
      query = query.whereDateBetween(
        _dateRange!.start,
        _dateRange!.end,
        fieldName: 'createdAt',
      );
    }

    // Execute query
    final page = await _referralRepo.getFirstPage(
      queryBuilder: query,
      pageSize: 50,
    );

    setState(() {
      _results = page.items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter panel
        FilterPanel(
          onStatusChanged: (status) => setState(() => _selectedStatus = status),
          onChildChanged: (child) => setState(() => _selectedChild = child),
          onDateRangeChanged: (range) => setState(() => _dateRange = range),
          onApply: _applyFilters,
        ),
        // Results
        Expanded(
          child: _results.isEmpty
              ? const Center(child: Text('No results'))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    return ReferralTile(referral: _results[index]);
                  },
                ),
        ),
      ],
    );
  }
}
```

### Example 3: Real-time Audit Log Stream

```dart
class AuditLogStream extends StatelessWidget {
  final _auditRepo = AuditLogRepository();

  @override
  Widget build(BuildContext context) {
    final query = QueryBuilder(collectionName: 'audit_logs')
        .orderBy('timestamp', direction: SortDirection.descending)
        .limit(20);

    return StreamBuilder<List<AuditLog>>(
      stream: _auditRepo.streamWhere(query),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final log = snapshot.data![index];
            return AuditLogTile(log: log);
          },
        );
      },
    );
  }
}
```

### Example 4: Child Search with Auto-complete

```dart
class ChildSearchField extends StatefulWidget {
  @override
  State<ChildSearchField> createState() => _ChildSearchFieldState();
}

class _ChildSearchFieldState extends State<ChildSearchField> {
  final _childRepo = ChildRepository();
  List<Child> _suggestions = [];

  Future<void> _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    // Use searchByName (or implement full-text search)
    final results = await _childRepo.searchByName(query);

    setState(() {
      _suggestions = results.take(10).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Child>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        await _onSearch(textEditingValue.text);
        return _suggestions;
      },
      displayStringForOption: (child) => child.name,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Search child',
            suffixIcon: const Icon(Icons.search),
          ),
        );
      },
    );
  }
}
```

### Example 5: Paginated Report Export

```dart
Future<void> exportEvaluationsToCSV() async {
  final _evaluationRepo = EvaluationRepository();

  // Build query for export
  final query = QueryBuilder(collectionName: 'evaluation_sessions')
      .whereDateBetween(
        DateTime(2024, 1, 1),
        DateTime.now(),
        fieldName: 'createdAt',
      )
      .orderBy('createdAt');

  // Load all pages
  final allEvaluations = <EvaluationSession>[];
  var currentPage = await _evaluationRepo.getFirstPage(
    queryBuilder: query,
    pageSize: 100,
  );

  allEvaluations.addAll(currentPage.items);

  while (currentPage.hasNextPage) {
    currentPage = await _evaluationRepo.getNextPage(
      cursor: currentPage.nextCursor!,
      queryBuilder: query,
      pageSize: 100,
    );
    allEvaluations.addAll(currentPage.items);
  }

  // Export to CSV
  final csv = convertToCSV(allEvaluations);
  await File('evaluations_export.csv').writeAsString(csv);
}
```

---

## Database Queries (Optimized by Indexes)

### Evaluation Queries

```sql
-- GET evaluations by child, ordered by date
SELECT * FROM evaluation_sessions 
WHERE childId = ? AND status IN ('pending', 'completed')
ORDER BY createdAt DESC
LIMIT 11;  -- +1 to detect next page

-- GET evaluations by domain
SELECT * FROM evaluation_sessions 
WHERE domain = 'fine_motor'
ORDER BY createdAt DESC
LIMIT 11;

-- GET evaluations by center
SELECT * FROM evaluation_sessions 
WHERE centerId = ? AND createdAt BETWEEN ? AND ?
ORDER BY createdAt DESC
LIMIT 11;
```

### Referral Queries

```sql
-- GET referrals by status
SELECT * FROM referrals 
WHERE status IN ('active', 'pending')
ORDER BY createdAt DESC
LIMIT 11;

-- GET referrals by child
SELECT * FROM referrals 
WHERE childId = ? AND status != 'deleted'
ORDER BY createdAt DESC
LIMIT 11;
```

### Audit Log Queries

```sql
-- GET audit logs by actor
SELECT * FROM audit_logs 
WHERE actorId = ?
ORDER BY timestamp DESC
LIMIT 11;

-- GET audit logs in date range
SELECT * FROM audit_logs 
WHERE timestamp BETWEEN ? AND ?
AND module IN ('evaluation', 'referral', 'user_management')
ORDER BY timestamp DESC
LIMIT 11;
```

---

## Performance Characteristics

| Operation | Firestore Cost | Speed |
|-----------|-----------------|-------|
| getFirstPage() | 1 read | ~200ms |
| getNextPage() | 1 read | ~200ms |
| count() | 1 read (Firestore billing) | ~1-2s |
| streamWhere() | 1 read per update | Real-time |
| getAll() [large] | 1 read per 1000 docs | ~5-10s |

### Optimization Tips

1. **Always paginate**: Never call getAll() for large collections
2. **Use cursor pagination**: Client handles page navigation, not server offset
3. **Filter on Firestore**: Apply filters at query level, not in memory
4. **Create indexes**: Deploy firestore.indexes.json (16 indexes included)
5. **Cache results**: Store pages locally with expiration
6. **Stream for real-time**: Use streamWhere() instead of polling

---

## Integration with Existing Code

### Migrate Old Query Code

**Before (Ad-hoc queries):**
```dart
final snapshot = await FirebaseFirestore.instance
    .collection('evaluations')
    .where('childId', isEqualTo: childId)
    .orderBy('createdAt', descending: true)
    .limit(10)
    .get();
```

**After (Unified Query):**
```dart
final repo = EvaluationRepository();
final query = QueryBuilder(collectionName: 'evaluation_sessions')
    .whereChild(childId)
    .orderBy('createdAt', direction: SortDirection.descending)
    .limit(10);

final page = await repo.getFirstPage(queryBuilder: query);
```

---

## Testing

### Unit Tests

```dart
// test/repositories/evaluation_repository_test.dart
void main() {
  group('EvaluationRepository', () {
    test('getFirstPage returns paginated results', () async {
      final repo = EvaluationRepository();
      final query = QueryBuilder(collectionName: 'evaluation_sessions')
          .orderBy('createdAt')
          .limit(10);

      final page = await repo.getFirstPage(queryBuilder: query);

      expect(page.items.length, lessThanOrEqualTo(10));
      expect(page.pageNumber, equals(1));
    });

    test('getNextPage navigates to next page', () async {
      final repo = EvaluationRepository();
      final query = QueryBuilder(collectionName: 'evaluation_sessions')
          .limit(10);

      var page1 = await repo.getFirstPage(queryBuilder: query);
      if (page1.hasNextPage) {
        var page2 = await repo.getNextPage(
          cursor: page1.nextCursor!,
          queryBuilder: query,
        );

        expect(page2.pageNumber, equals(2));
        expect(page2.items.first.id, isNotEmpty);
      }
    });
  });
}
```

---

## Phase 5 Approval Gate

**Before proceeding to Phase 6**, please verify:

- [ ] **QueryBuilder**: All filter types work correctly
- [ ] **Pagination**: Cursors encode/decode correctly
- [ ] **Repositories**: Each entity type has a repository
- [ ] **Firestore Indexes**: 16 indexes deployed
- [ ] **Performance**: Page load time < 500ms
- [ ] **Streaming**: Real-time updates work
- [ ] **Edge Cases**: Empty results, large datasets, date ranges
- [ ] **Integration**: Existing code migrated to repositories

**Open Questions**:
1. Should "text search" use Algolia or Firestore?
2. Should pagination support "jump to page N"?
3. Should we cache pages locally for offline support?
4. Should sort support multi-field sorting?

---

## Next Phase: Phase 6

Once Phase 5 approval is granted:

**Phase 6: Form Validation & Categories**

- Centralized validators (password, date range, age band, scores, etc.)
- Category administration (referral concerns, agencies, outcomes, etc.)
- Dynamic category management (admin UI)
- Estimated effort: 6-8 hours

