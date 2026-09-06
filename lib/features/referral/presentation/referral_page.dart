import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../auth/data/auth_repository_impl.dart';

class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  List<Map<String, dynamic>> _referrals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReferrals();
  }

  Future<void> _loadReferrals() async {
    setState(() => _isLoading = true);
    final teacher = await AuthRepositoryImpl().getCurrentUser();
    if (teacher != null) {
      final data = await DatabaseHelper.instance.getReferralsByTeacher(teacher.id!);
      setState(() {
        _referrals = data;
        _isLoading = false;
      });
    }
  }

  void _showAddReferralDialog() async {
    final teacher = await AuthRepositoryImpl().getCurrentUser();
    if (teacher == null) return;

    final children = await DatabaseHelper.instance.readChildrenByTeacher(teacher.id!);
    if (children.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Register a child first to create referrals.')),
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddReferralSheet(
        children: children,
        onSaved: () {
          Navigator.pop(context);
          _loadReferrals();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Referrals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddReferralDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Referral'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _referrals.isEmpty
              ? const Center(child: Text('No referrals created yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _referrals.length,
                  itemBuilder: (context, index) {
                    final referral = _referrals[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.medical_information),
                        ),
                        title: Text(
                          '${referral['child_name']} - ${referral['category']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(referral['reason']),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                referral['status'],
                                style: const TextStyle(fontSize: 12, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(referral['date']),
                      ),
                    );
                  },
                ),
    );
  }
}

class _AddReferralSheet extends StatefulWidget {
  final List<ChildModel> children;
  final VoidCallback onSaved;
  const _AddReferralSheet({required this.children, required this.onSaved});

  @override
  State<_AddReferralSheet> createState() => _AddReferralSheetState();
}

class _AddReferralSheetState extends State<_AddReferralSheet> {
  final _reasonController = TextEditingController();
  ChildModel? _selectedChild;
  String _selectedCategory = 'Health/Medical';
  bool _isSaving = false;

  final List<String> _categories = [
    'Health/Medical',
    'Developmental Delay',
    'Nutritional Support',
    'Social Services',
    'Special Education',
  ];

  @override
  void initState() {
    super.initState();
    _selectedChild = widget.children.first;
  }

  void _submit() async {
    if (_reasonController.text.isEmpty) return;

    setState(() => _isSaving = true);
    final teacher = await AuthRepositoryImpl().getCurrentUser();

    await DatabaseHelper.instance.createReferral(
      _selectedChild!.id!,
      teacher!.id!,
      _selectedCategory,
      _reasonController.text,
    );

    setState(() => _isSaving = false);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Create Referral', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<ChildModel>(
            initialValue: _selectedChild,
            decoration: const InputDecoration(labelText: 'Select Child', border: OutlineInputBorder()),
            items: widget.children.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
            onChanged: (val) => setState(() => _selectedChild = val),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(labelText: 'Referral Category', border: OutlineInputBorder()),
            items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
            onChanged: (val) => setState(() => _selectedCategory = val!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason for Referral', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _submit,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _isSaving ? const CircularProgressIndicator() : const Text('Submit Referral'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
