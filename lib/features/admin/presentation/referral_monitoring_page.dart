import 'package:flutter/material.dart';
import '../../referral/data/referral_repository.dart';
import '../../referral/domain/referral_model.dart';

class ReferralMonitoringPage extends StatefulWidget {
  const ReferralMonitoringPage({super.key});

  @override
  State<ReferralMonitoringPage> createState() => _ReferralMonitoringPageState();
}

class _ReferralMonitoringPageState extends State<ReferralMonitoringPage> {
  final ReferralRepository _repository = ReferralRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allReferrals = [];
  List<Map<String, dynamic>> _filteredReferrals = [];
  String _searchQuery = '';
  String _selectedFilter = 'All';
  bool _isLoading = true;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  int _currentPage = 0;
  static const int _itemsPerPage = 10;

  final List<String> _statusFilters = [
    'All',
    'Pending',
    'Referred',
    'For Follow-Up',
    'Completed',
    'Closed'
  ];

  @override
  void initState() {
    super.initState();
    _loadReferrals();
  }

  Future<void> _loadReferrals() async {
    setState(() => _isLoading = true);
    final data = await _repository.getAllReferrals();
    setState(() {
      _allReferrals = data;
      _applyFilterAndSort();
      _isLoading = false;
    });
  }

  void _applyFilterAndSort() {
    setState(() {
      final q = _searchQuery.toLowerCase();
      
      _filteredReferrals = _allReferrals.where((r) {
        final childName = "${r['first_name']} ${r['last_name']}".toLowerCase();
        final concern = (r['concern'] as String? ?? '').toLowerCase();
        final status = (r['status'] as String? ?? '').toLowerCase();

        final matchesSearch = childName.contains(q) || concern.contains(q) || status.contains(q);
        final matchesStatus = _selectedFilter == 'All' || r['status'] == _selectedFilter;

        return matchesSearch && matchesStatus;
      }).toList();

      if (_sortColumnIndex != null) {
        _filteredReferrals.sort((a, b) {
          int result = 0;
          switch (_sortColumnIndex) {
            case 0:
              final nameA = "${a['first_name']} ${a['last_name']}".toLowerCase();
              final nameB = "${b['first_name']} ${b['last_name']}".toLowerCase();
              result = nameA.compareTo(nameB);
              break;
            case 1:
              result = (a['concern'] as String? ?? '').compareTo(b['concern'] as String? ?? '');
              break;
            case 2:
              result = (a['referral_date'] as String? ?? '').compareTo(b['referral_date'] as String? ?? '');
              break;
            case 3:
              result = (a['follow_up_date'] as String? ?? '').compareTo(b['follow_up_date'] as String? ?? '');
              break;
            case 4:
              result = (a['status'] as String? ?? '').compareTo(b['status'] as String? ?? '');
              break;
          }
          return _sortAscending ? result : -result;
        });
      }
    });
  }

  void _sort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _applyFilterAndSort();
    });
  }

  void _updateStatus(Map<String, dynamic> referralData) async {
    final referral = ReferralModel.fromMap(referralData);
    String tempStatus = referral.status;

    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Referral Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _statusFilters.where((s) => s != 'All').map((status) {
            return RadioListTile<String>(
              title: Text(status),
              value: status,
              groupValue: tempStatus,
              onChanged: (val) => Navigator.pop(context, val),
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );

    if (newStatus != null && newStatus != referral.status) {
      await _repository.updateReferral(referral.copyWith(status: newStatus));
      _loadReferrals();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _filteredReferrals.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();

    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }

    final paginatedReferrals = _filteredReferrals
        .skip(_currentPage * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('MSWD Referral Monitoring'),
      ),
      body: Column(
        children: [
          _buildSearchAndFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReferrals.isEmpty
                    ? const Center(child: Text('No matching referral records found.'))
                    : Column(
                        children: [
                          Expanded(child: _buildReferralTable(paginatedReferrals)),
                          _buildPaginationControls(totalItems, totalPages),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = SearchBar(
            controller: _searchController,
            hintText: 'Search referrals by child, concern, or status...',
            leading: const Icon(Icons.search),
            onChanged: (val) {
              _searchQuery = val;
              _currentPage = 0;
              _applyFilterAndSort();
            },
          );
          final filter = DropdownButtonFormField<String>(
            initialValue: _selectedFilter,
            decoration: const InputDecoration(
              labelText: 'Filter status',
              prefixIcon: Icon(Icons.filter_list),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _statusFilters.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
            onChanged: (value) {
              setState(() {
                _selectedFilter = value ?? 'All';
                _currentPage = 0;
              });
              _applyFilterAndSort();
            },
          );
          if (constraints.maxWidth < 680) {
            return Column(children: [search, const SizedBox(height: 10), filter]);
          }
          return Row(children: [Expanded(child: search), const SizedBox(width: 16), SizedBox(width: 220, child: filter)]);
        },
      ),
    );
  }

  Widget _buildReferralTable(List<Map<String, dynamic>> paginatedReferrals) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 1200,
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: DataTable(
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainer),
            columns: [
              DataColumn(
                label: const Text('Child Name', style: TextStyle(fontWeight: FontWeight.bold)),
                onSort: (index, ascending) => _sort(index, ascending),
              ),
              DataColumn(
                label: const Text('Concern', style: TextStyle(fontWeight: FontWeight.bold)),
                onSort: (index, ascending) => _sort(index, ascending),
              ),
              DataColumn(
                label: const Text('Referral Date', style: TextStyle(fontWeight: FontWeight.bold)),
                onSort: (index, ascending) => _sort(index, ascending),
              ),
              DataColumn(
                label: const Text('Follow-Up', style: TextStyle(fontWeight: FontWeight.bold)),
                onSort: (index, ascending) => _sort(index, ascending),
              ),
              DataColumn(
                label: const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                onSort: (index, ascending) => _sort(index, ascending),
              ),
              const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: paginatedReferrals.map((r) {
              final statusColor = _getStatusColor(r['status']);
              return DataRow(cells: [
                DataCell(Text('${r['first_name']} ${r['last_name']}')),
                DataCell(Text(r['concern'])),
                DataCell(Text(r['referral_date'])),
                DataCell(Text(r['follow_up_date'])),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      r['status'],
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.edit_note, color: Colors.blue),
                    onPressed: () => _updateStatus(r),
                    tooltip: 'Update Status',
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
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
            'Showing $startItem - $endItem of $totalItems referrals',
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending': return Colors.orange;
      case 'Referred': return Colors.blue;
      case 'For Follow-Up': return Colors.purple;
      case 'Completed': return Colors.green;
      case 'Closed': return Colors.grey;
      default: return Colors.black;
    }
  }
}
