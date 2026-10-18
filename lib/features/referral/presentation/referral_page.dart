import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../data/referral_repository.dart';
import '../domain/referral_model.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  final ReferralRepository _repository = ReferralRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allReferrals = [];
  List<Map<String, dynamic>> _filteredReferrals = [];
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';
  String _sortBy = 'Date Newest First';
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
    _allReferrals = await _repository.getAllReferrals();
    _applyFilterAndSort();
    setState(() => _isLoading = false);
  }

  void _applyFilterAndSort() {
    setState(() {
      final q = _searchQuery.toLowerCase();
      _filteredReferrals = _allReferrals.where((item) {
        final childName = "${item['first_name']} ${item['last_name']}".toLowerCase();
        final childId = (item['child_id'] as String? ?? '').toLowerCase();
        final concern = (item['concern'] as String? ?? '').toLowerCase();
        final status = (item['status'] as String? ?? '').toLowerCase();

        final matchesSearch = childName.contains(q) || childId.contains(q) || concern.contains(q) || status.contains(q);
        final matchesStatus = _selectedStatusFilter == 'All' ||
            status.toLowerCase() == _selectedStatusFilter.toLowerCase();

        return matchesSearch && matchesStatus;
      }).toList();

      _filteredReferrals.sort((a, b) {
        final dateA = (a['referral_date'] as String? ?? '');
        final dateB = (b['referral_date'] as String? ?? '');
        switch (_sortBy) {
          case 'Name A-Z':
            return "${a['first_name']} ${a['last_name']}".toLowerCase().compareTo("${b['first_name']} ${b['last_name']}".toLowerCase());
          case 'Date Oldest First':
            return dateA.compareTo(dateB);
          case 'Date Newest First':
          default:
            return dateB.compareTo(dateA);
        }
      });
    });
  }

  void _showReferralForm({Map<String, dynamic>? existingReferral}) async {
    final children = await DatabaseHelper.instance.getAllChildren();
    if (children.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No children registered yet.')));
      }
      return;
    }

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _ReferralFormDialog(
        children: children,
        referral: existingReferral != null ? ReferralModel.fromMap(existingReferral) : null,
      ),
    );

    if (result == true) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referrals & Cases'),
        actions: [
          IconButton(onPressed: _loadReferrals, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showReferralForm(),
        label: const Text('New Referral'),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search by Child ID, Child Name, or Concern...',
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
                : _filteredReferrals.isEmpty
                    ? const Center(child: Text('No matching referrals found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredReferrals.length,
                        itemBuilder: (context, index) {
                          final item = _filteredReferrals[index];
                          final status = item['status'];
                          final color = _getStatusColor(status);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.1),
                                child: Icon(Icons.assignment_late, color: color),
                              ),
                              title: Text('${item['first_name']} ${item['last_name']} (${item['child_id']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Concern: ${item['concern']}'),
                                  Text('Date: ${item['referral_date']}', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
                              ),
                              onTap: () => _showReferralForm(existingReferral: item),
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
          const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusFilters.map((status) {
                  final isSelected = _selectedStatusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(status == 'All' ? 'All Status' : status, style: const TextStyle(fontSize: 11)),
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
          SizedBox(
            width: 150,
            child: DropdownButton<String>(
              value: _sortBy,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.sort, size: 20),
              items: ['Date Newest First', 'Date Oldest First', 'Name A-Z']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))))
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

class _ReferralFormDialog extends StatefulWidget {
  final List<ChildModel> children;
  final ReferralModel? referral;
  const _ReferralFormDialog({required this.children, this.referral});

  @override
  State<_ReferralFormDialog> createState() => _ReferralFormDialogState();
}

class _ReferralFormDialogState extends State<_ReferralFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ReferralRepositoryImpl();
  final _descController = TextEditingController();
  final _notesController = TextEditingController();

  static const _developmentalConcerns = [
    'Gross Motor',
    'Fine Motor',
    'Self-Help',
    'Language',
    'Cognitive',
    'Social-Emotional',
  ];
  final List<String> _concernOptions = [..._developmentalConcerns];
  
  ChildModel? _selectedChild;
  String _selectedConcern = _developmentalConcerns.first;
  String _selectedStatus = 'Pending';
  DateTime _referralDate = DateTime.now();
  DateTime _followUpDate = DateTime.now().add(const Duration(days: 14));

  @override
  void initState() {
    super.initState();
    if (widget.referral != null) {
      if (!_concernOptions.contains(widget.referral!.concern)) {
        _concernOptions.add(widget.referral!.concern);
      }
      _selectedConcern = widget.referral!.concern;
      _descController.text = widget.referral!.description;
      _notesController.text = widget.referral!.followUpNotes ?? '';
      _selectedStatus = widget.referral!.status;
      _referralDate = DateTime.parse(widget.referral!.referralDate);
      _followUpDate = DateTime.parse(widget.referral!.followUpDate);
      _selectedChild = widget.children.firstWhere((c) => c.childId == widget.referral!.childId);
    } else {
      _selectedChild = widget.children.first;
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedChild == null) return;

      if (widget.referral != null) {
        final confirmed = await ConfirmationDialog.showEdit(
          context: context,
          itemName: 'Referral for ${_selectedChild!.firstName}',
        );
        if (!confirmed) return;
      }

      final referral = ReferralModel(
        id: widget.referral?.id,
        childId: _selectedChild!.childId,
        concern: _selectedConcern,
        description: _descController.text.trim(),
        referralDate: DateFormat('yyyy-MM-dd HH:mm:ss').format(_referralDate),
        followUpDate: DateFormat('yyyy-MM-dd HH:mm:ss').format(_followUpDate),
        status: _selectedStatus,
        followUpNotes: _notesController.text.trim(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      if (widget.referral != null) {
        await _repository.updateReferral(referral);
      } else {
        await _repository.addReferral(referral);
      }

      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<_TimeWithSeconds?> _showTimeWithSecondsPicker(DateTime initialTime) {
    var hour = initialTime.hour;
    var minute = initialTime.minute;
    var second = initialTime.second;
    final hourController = FixedExtentScrollController(initialItem: hour);
    final minuteController = FixedExtentScrollController(initialItem: minute);
    final secondController = FixedExtentScrollController(initialItem: second);

    return showDialog<_TimeWithSeconds>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set time'),
          content: SizedBox(
            height: 230,
            width: double.maxFinite,
            child: Row(
              children: [
                Expanded(child: _timeWheel('Hour', 24, hourController, (value) => setDialogState(() => hour = value))),
                Expanded(child: _timeWheel('Minute', 60, minuteController, (value) => setDialogState(() => minute = value))),
                Expanded(child: _timeWheel('Second', 60, secondController, (value) => setDialogState(() => second = value))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, _TimeWithSeconds(hour, minute, second)), child: const Text('Set time')),
          ],
        ),
      ),
    );
  }

  Widget _timeWheel(
    String label,
    int itemCount,
    FixedExtentScrollController controller,
    ValueChanged<int> onChanged,
  ) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: CupertinoPicker.builder(
              scrollController: controller,
              itemExtent: 44,
              selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(background: Colors.transparent),
              onSelectedItemChanged: onChanged,
              childCount: itemCount,
              itemBuilder: (context, index) => Center(
                child: Text(index.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _descController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Text(widget.referral != null ? 'Update Referral' : 'New Referral'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ChildModel>(
                initialValue: _selectedChild,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Child'),
                items: widget.children.map((c) => DropdownMenuItem(value: c, child: Text("${c.firstName} ${c.lastName} (${c.childId})", overflow: TextOverflow.ellipsis))).toList(),
                onChanged: widget.referral != null ? null : (val) => setState(() => _selectedChild = val),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedConcern,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Developmental Concern'),
                items: _concernOptions
                    .map((concern) => DropdownMenuItem(value: concern, child: Text(concern, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedConcern = value ?? _selectedConcern),
                validator: (value) => Validators.validateRequired(value, 'Developmental Concern'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
                validator: (v) => Validators.validateRequired(v, 'Description'),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Referral Date', style: TextStyle(fontSize: 14)),
                subtitle: Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(_referralDate)),
                trailing: const Icon(Icons.calendar_today, size: 20),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _referralDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (picked != null) {
                    setState(() => _referralDate = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      _referralDate.hour,
                      _referralDate.minute,
                      _referralDate.second,
                    ));
                  }
                },
              ),
              ListTile(
                title: const Text('Referral Time', style: TextStyle(fontSize: 14)),
                subtitle: Text(DateFormat('HH:mm:ss').format(_referralDate)),
                trailing: const Icon(Icons.schedule, size: 20),
                onTap: () async {
                  final picked = await _showTimeWithSecondsPicker(_referralDate);
                  if (picked != null) {
                    setState(() => _referralDate = DateTime(
                      _referralDate.year,
                      _referralDate.month,
                      _referralDate.day,
                      picked.hour,
                      picked.minute,
                      picked.second,
                    ));
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Follow-up Date', style: TextStyle(fontSize: 14)),
                subtitle: Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(_followUpDate)),
                trailing: const Icon(Icons.calendar_today, size: 20),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _followUpDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) {
                    setState(() => _followUpDate = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      _followUpDate.hour,
                      _followUpDate.minute,
                      _followUpDate.second,
                    ));
                  }
                },
              ),
              ListTile(
                title: const Text('Follow-up Time', style: TextStyle(fontSize: 14)),
                subtitle: Text(DateFormat('HH:mm:ss').format(_followUpDate)),
                trailing: const Icon(Icons.schedule, size: 20),
                onTap: () async {
                  final picked = await _showTimeWithSecondsPicker(_followUpDate);
                  if (picked != null) {
                    setState(() => _followUpDate = DateTime(
                      _followUpDate.year,
                      _followUpDate.month,
                      _followUpDate.day,
                      picked.hour,
                      picked.minute,
                      picked.second,
                    ));
                  }
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['Pending', 'Referred', 'For Follow-Up', 'Completed', 'Closed'].map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) => setState(() => _selectedStatus = val!),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Follow-up Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _TimeWithSeconds {
  const _TimeWithSeconds(this.hour, this.minute, this.second);

  final int hour;
  final int minute;
  final int second;
}
