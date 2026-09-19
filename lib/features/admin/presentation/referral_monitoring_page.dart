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
  List<Map<String, dynamic>> _allReferrals = [];
  List<Map<String, dynamic>> _filteredReferrals = [];
  String _selectedFilter = 'All';
  bool _isLoading = true;

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
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    setState(() {
      if (_selectedFilter == 'All') {
        _filteredReferrals = _allReferrals;
      } else {
        _filteredReferrals = _allReferrals
            .where((r) => r['status'] == _selectedFilter)
            .toList();
      }
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MSWD Referral Monitoring'),
        actions: [
          IconButton(onPressed: _loadReferrals, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReferrals.isEmpty
                    ? const Center(child: Text('No referrals found for this status.'))
                    : _buildReferralTable(),
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
          const Icon(Icons.filter_list, size: 20),
          const SizedBox(width: 12),
          const Text('Filter Status:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusFilters.map((status) {
                  final isSelected = _selectedFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedFilter = status;
                            _applyFilter();
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.primaryContainer),
            columns: const [
              DataColumn(label: Text('Child Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Concern', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Referral Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Follow-Up', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _filteredReferrals.map((r) {
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
