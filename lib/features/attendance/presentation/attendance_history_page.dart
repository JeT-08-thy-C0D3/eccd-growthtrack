import 'package:flutter/material.dart';

import '../../../shared/models/child_model.dart';
import '../data/attendance_repository.dart';

class AttendanceHistoryPage extends StatefulWidget {
  final ChildModel child;
  const AttendanceHistoryPage({super.key, required this.child});

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  final AttendanceRepository _repository = AttendanceRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allHistory = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';
  String _sortBy = 'Newest First';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final data = await _repository.getHistory(widget.child.childId);
    setState(() {
      _allHistory = data;
      _applyFilterAndSort();
      _isLoading = false;
    });
  }

  void _applyFilterAndSort() {
    setState(() {
      final q = _searchQuery.toLowerCase();
      _filteredHistory = _allHistory.where((record) {
        final date = (record['attendance_date'] as String? ?? '').toLowerCase();
        final time = (record['attendance_time'] as String? ?? '').toLowerCase();
        final childName = "${widget.child.firstName} ${widget.child.lastName}"
            .toLowerCase();
        final childId = widget.child.childId.toLowerCase();

        final matchesSearch =
            date.contains(q) ||
            time.contains(q) ||
            childName.contains(q) ||
            childId.contains(q);
        final matchesStatus =
            _selectedStatusFilter == 'All' ||
            (record['status'] as String? ?? '').toLowerCase() ==
                _selectedStatusFilter.toLowerCase();

        return matchesSearch && matchesStatus;
      }).toList();

      _filteredHistory.sort((a, b) {
        final dateA = (a['attendance_date'] as String? ?? '');
        final dateB = (b['attendance_date'] as String? ?? '');
        if (_sortBy == 'Oldest First') {
          return dateA.compareTo(dateB);
        } else {
          return dateB.compareTo(dateA);
        }
      });
    });
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
        title: Text(
          'History: ${widget.child.firstName} (${widget.child.childId})',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search by Date, Time, Name, or Child ID...',
              leading: const Icon(Icons.search),
              onChanged: (val) {
                _searchQuery = val;
                _applyFilterAndSort();
              },
            ),
          ),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredHistory.isEmpty
                ? const Center(
                    child: Text('No matching attendance records found.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredHistory.length,
                    itemBuilder: (context, index) {
                      final record = _filteredHistory[index];
                      final isPresent = record['status'] == 'Present';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            isPresent ? Icons.check_circle : Icons.cancel,
                            color: isPresent ? Colors.green : Colors.red,
                          ),
                          title: Text(record['attendance_date']),
                          subtitle: Text(
                            'Time In: ${record['attendance_time']} • Method: ${(record['attendance_method'] ?? 'manual').toString().toUpperCase()}',
                          ),
                          trailing: Text(
                            record['status'],
                            style: TextStyle(
                              color: isPresent ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Status:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Present', 'Absent'].map((status) {
                  final isSelected = _selectedStatusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(status, style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedStatusFilter = status;
                            _applyFilterAndSort();
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          DropdownButton<String>(
            value: _sortBy,
            underline: const SizedBox(),
            icon: const Icon(Icons.sort, size: 20),
            items: ['Newest First', 'Oldest First']
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, style: const TextStyle(fontSize: 12)),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _sortBy = val;
                  _applyFilterAndSort();
                });
              }
            },
          ),
        ],
      ),
    );
  }
}
