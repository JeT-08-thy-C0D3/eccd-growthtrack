import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../core/utils/validators.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/clarification_repository.dart';
import '../domain/clarification_model.dart';

class ParentClarificationPage extends StatefulWidget {
  const ParentClarificationPage({super.key});

  @override
  State<ParentClarificationPage> createState() => _ParentClarificationPageState();
}

class _ParentClarificationPageState extends State<ParentClarificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ClarificationRepositoryImpl();
  
  List<ChildModel> _children = [];
  ChildModel? _selectedChild;
  List<ClarificationModel> _requests = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final _messageController = TextEditingController();
  String _selectedCategory = 'General Concern';

  final List<String> _categories = [
    'Assessment',
    'Home Activity',
    'Referral',
    'General Concern',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = await AuthRepositoryImpl().getCurrentUser();
    if (user != null) {
      final children = await DatabaseHelper.instance.readChildrenByParent(user.uid);
      if (children.isNotEmpty) {
        _children = children;
        _selectedChild = children.first;
        await _loadRequests();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRequests() async {
    if (_selectedChild == null) return;
    final requests = await _repository.getRequestsByChild(_selectedChild!.childId);
    setState(() {
      _requests = requests;
      _isLoading = false;
    });
  }

  void _submitQuestion() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedChild == null) return;

      setState(() => _isSaving = true);
      final user = await AuthRepositoryImpl().getCurrentUser();
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      int parentId = user?.id ?? 0;

      final request = ClarificationModel(
        childId: _selectedChild!.childId,
        parentId: parentId,
        category: _selectedCategory,
        message: _messageController.text.trim(),
        status: 'Pending',
        createdAt: now,
        updatedAt: now,
        isSynced: false,
      );

      await _repository.sendRequest(request);

      _messageController.clear();
      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clarification request submitted to teacher!')),
        );
        _loadRequests();
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clarification Requests')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _children.isEmpty
              ? const Center(child: Text('No children linked to your account.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Submit a Question to Teacher',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<ChildModel>(
                                  value: _selectedChild,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Child',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.child_care),
                                  ),
                                  items: _children.map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text("${c.firstName} ${c.lastName} (${c.childId})"),
                                  )).toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedChild = val);
                                    _loadRequests();
                                  },
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _selectedCategory,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.category),
                                  ),
                                  items: _categories.map((cat) => DropdownMenuItem(
                                    value: cat,
                                    child: Text(cat),
                                  )).toList(),
                                  onChanged: (val) => setState(() => _selectedCategory = val!),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _messageController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Your Question / Clarification',
                                    border: OutlineInputBorder(),
                                    hintText: 'Type your question or clarification details for the teacher...',
                                    alignLabelWithHint: true,
                                  ),
                                  validator: (v) => Validators.validateRequired(v, 'Question / Clarification'),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _isSaving ? null : _submitQuestion,
                                  icon: const Icon(Icons.send),
                                  label: Text(_isSaving ? 'Submitting...' : 'Submit Request'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          const Icon(Icons.history, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Request History (${_requests.length})',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_requests.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text('No clarification requests submitted yet.'),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _requests.length,
                          itemBuilder: (context, index) {
                            final item = _requests[index];
                            final isResponded = item.status == 'Responded';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Chip(
                                          label: Text(item.category, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isResponded ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            item.status,
                                            style: TextStyle(
                                              color: isResponded ? Colors.green : Colors.orange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Q: ${item.message}',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Submitted: ${item.createdAt}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    if (isResponded && item.response != null) ...[
                                      const Divider(height: 20),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Row(
                                              children: [
                                                Icon(Icons.mark_chat_read, size: 16, color: Colors.green),
                                                SizedBox(width: 6),
                                                Text('Teacher Response:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(item.response!, style: const TextStyle(fontSize: 14)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }
}
