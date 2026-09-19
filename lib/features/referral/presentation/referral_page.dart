import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../data/referral_repository.dart';
import '../domain/referral_model.dart';
import 'referral_history_page.dart';

class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  final ReferralRepository _repository = ReferralRepositoryImpl();
  List<Map<String, dynamic>> _referrals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReferrals();
  }

  Future<void> _loadReferrals() async {
    setState(() => _isLoading = true);
    _referrals = await _repository.getAllReferrals();
    setState(() => _isLoading = false);
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _referrals.isEmpty
              ? const Center(child: Text('No active referrals found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _referrals.length,
                  itemBuilder: (context, index) {
                    final item = _referrals[index];
                    final status = item['status'];
                    final color = _getStatusColor(status);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.1),
                          child: Icon(Icons.assignment_late, color: color),
                        ),
                        title: Text('${item['first_name']} ${item['last_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
  final _repository = ReferralRepositoryImpl();
  final _concernController = TextEditingController();
  final _descController = TextEditingController();
  final _notesController = TextEditingController();
  
  ChildModel? _selectedChild;
  String _selectedStatus = 'Pending';
  DateTime _referralDate = DateTime.now();
  DateTime _followUpDate = DateTime.now().add(const Duration(days: 14));

  @override
  void initState() {
    super.initState();
    if (widget.referral != null) {
      _concernController.text = widget.referral!.concern;
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
    if (_concernController.text.isEmpty || _selectedChild == null) return;

    final referral = ReferralModel(
      id: widget.referral?.id,
      childId: _selectedChild!.childId,
      concern: _concernController.text,
      description: _descController.text,
      referralDate: DateFormat('yyyy-MM-dd').format(_referralDate),
      followUpDate: DateFormat('yyyy-MM-dd').format(_followUpDate),
      status: _selectedStatus,
      followUpNotes: _notesController.text,
      updatedAt: DateTime.now().toIso8601String(),
    );

    if (widget.referral != null) {
      await _repository.updateReferral(referral);
    } else {
      await _repository.addReferral(referral);
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.referral != null ? 'Update Referral' : 'New Referral'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<ChildModel>(
              value: _selectedChild,
              decoration: const InputDecoration(labelText: 'Child'),
              items: widget.children.map((c) => DropdownMenuItem(value: c, child: Text("${c.firstName} ${c.lastName}"))).toList(),
              onChanged: widget.referral != null ? null : (val) => setState(() => _selectedChild = val),
            ),
            TextField(controller: _concernController, decoration: const InputDecoration(labelText: 'Developmental Concern')),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Referral Date', style: TextStyle(fontSize: 14)),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(_referralDate)),
              trailing: const Icon(Icons.calendar_today, size: 20),
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _referralDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                if (picked != null) setState(() => _referralDate = picked);
              },
            ),
            ListTile(
              title: const Text('Follow-up Date', style: TextStyle(fontSize: 14)),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(_followUpDate)),
              trailing: const Icon(Icons.calendar_today, size: 20),
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _followUpDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (picked != null) setState(() => _followUpDate = picked);
              },
            ),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: ['Pending', 'Referred', 'For Follow-Up', 'Completed', 'Closed'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _selectedStatus = val!),
            ),
            TextField(controller: _notesController, decoration: const InputDecoration(labelText: 'Follow-up Notes'), maxLines: 2),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
