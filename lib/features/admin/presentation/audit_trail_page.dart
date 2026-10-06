import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/repositories/audit_repository.dart';
import '../domain/audit_log_model.dart';

class AuditTrailPage extends StatefulWidget {
  const AuditTrailPage({super.key});

  @override
  State<AuditTrailPage> createState() => _AuditTrailPageState();
}

class _AuditTrailPageState extends State<AuditTrailPage> {
  final AuditRepository _repository = AuditRepository();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedActionFilter;
  int? _sortColumnIndex;
  bool _sortAscending = false; // Default timestamp descending
  int _currentPage = 0;
  static const int _itemsPerPage = 10;

  final List<String> _trackedActions = [
    'User Created',
    'User Updated',
    'User Deleted',
    'Referral Updated',
    'Report Generated',
  ];

  void _sort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  List<AuditLogModel> _filterAndSortLogs(List<AuditLogModel> logs) {
    var filtered = logs.where((log) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = log.action.toLowerCase().contains(q) ||
          log.performedBy.toLowerCase().contains(q) ||
          log.targetRecord.toLowerCase().contains(q);
      final matchesAction = _selectedActionFilter == null || log.action == _selectedActionFilter;
      return matchesSearch && matchesAction;
    }).toList();

    if (_sortColumnIndex != null) {
      filtered.sort((a, b) {
        int result = 0;
        switch (_sortColumnIndex) {
          case 0:
            result = a.timestamp.compareTo(b.timestamp);
            break;
          case 1:
            result = a.action.compareTo(b.action);
            break;
          case 2:
            result = a.performedBy.compareTo(b.performedBy);
            break;
          case 3:
            result = a.targetRecord.compareTo(b.targetRecord);
            break;
        }
        return _sortAscending ? result : -result;
      });
    }

    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Audit Trail'),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<List<AuditLogModel>>(
              stream: _repository.streamLogs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No audit logs found.'));
                }

                final filteredLogs = _filterAndSortLogs(snapshot.data!);
                final totalItems = filteredLogs.length;
                final totalPages = (totalItems / _itemsPerPage).ceil();

                if (_currentPage >= totalPages && totalPages > 0) {
                  _currentPage = totalPages - 1;
                }

                final paginatedLogs = filteredLogs
                    .skip(_currentPage * _itemsPerPage)
                    .take(_itemsPerPage)
                    .toList();

                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: SizedBox(
                            width: double.infinity,
                            child: DataTable(
                              sortColumnIndex: _sortColumnIndex,
                              sortAscending: _sortAscending,
                              headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
                              columns: [
                                DataColumn(
                                  label: const Text('Timestamp', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onSort: (index, ascending) => _sort(index, ascending),
                                ),
                                DataColumn(
                                  label: const Text('Action', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onSort: (index, ascending) => _sort(index, ascending),
                                ),
                                DataColumn(
                                  label: const Text('Performed By', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onSort: (index, ascending) => _sort(index, ascending),
                                ),
                                DataColumn(
                                  label: const Text('Target Record', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onSort: (index, ascending) => _sort(index, ascending),
                                ),
                              ],
                              rows: paginatedLogs.map((log) {
                                return DataRow(cells: [
                                  DataCell(Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp))),
                                  DataCell(_buildActionBadge(log.action)),
                                  DataCell(Text(log.performedBy, style: const TextStyle(fontWeight: FontWeight.w500))),
                                  DataCell(Text(log.targetRecord)),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildPaginationControls(totalItems, totalPages),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search logs by Action, Performed By, or Target Record...',
              leading: const Icon(Icons.search),
              onChanged: (value) => setState(() {
                _searchQuery = value;
                _currentPage = 0;
              }),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedActionFilter,
              decoration: const InputDecoration(
                labelText: 'Filter Action',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Actions')),
                ..._trackedActions.map((a) => DropdownMenuItem(value: a, child: Text(a))),
              ],
              onChanged: (val) => setState(() {
                _selectedActionFilter = val;
                _currentPage = 0;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBadge(String action) {
    Color color = Colors.grey;
    if (action.contains('User Created')) color = Colors.blue;
    if (action.contains('User Updated')) color = Colors.orange;
    if (action.contains('User Deleted')) color = Colors.red;
    if (action.contains('Referral Updated')) color = Colors.purple;
    if (action.contains('Report Generated')) color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        action,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildPaginationControls(int totalItems, int totalPages) {
    if (totalItems == 0) return const SizedBox.shrink();

    final startItem = (_currentPage * _itemsPerPage) + 1;
    final endItem = ((_currentPage + 1) * _itemsPerPage) > totalItems
        ? totalItems
        : (_currentPage + 1) * _itemsPerPage;
    final displayTotalPages = totalPages == 0 ? 1 : totalPages;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startItem - $endItem of $totalItems records',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                tooltip: 'Previous Page',
              ),
              Text(
                'Page ${_currentPage + 1} of $displayTotalPages',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage + 1 < displayTotalPages ? () => setState(() => _currentPage++) : null,
                tooltip: 'Next Page',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
