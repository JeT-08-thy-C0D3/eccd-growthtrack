import 'package:flutter/material.dart';
import '../../parent/data/clarification_repository.dart';
import '../../../core/utils/validators.dart';
import '../../auth/data/auth_repository_impl.dart';

class TeacherClarificationsPage extends StatefulWidget {
  const TeacherClarificationsPage({super.key});

  @override
  State<TeacherClarificationsPage> createState() => _TeacherClarificationsPageState();
}

class _TeacherClarificationsPageState extends State<TeacherClarificationsPage> {
  final _repository = ClarificationRepositoryImpl();
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _filteredRequests = [];
  String _selectedStatusFilter = 'All';
  String _selectedCategoryFilter = 'All';
  bool _isLoading = true;

  final List<String> _statusFilters = ['All', 'Pending', 'Responded'];
  final List<String> _categoryFilters = [
    'All',
    'Assessment',
    'Home Activity',
    'Referral',
    'General Concern',
  ];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final data = await _repository.getAllRequestsWithChild();
    setState(() {
      _allRequests = data;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredRequests = _allRequests.where((item) {
        final status = (item['status'] as String? ?? 'Pending').toLowerCase();
        final category = (item['category'] as String? ?? 'General Concern').toLowerCase();

        final matchesStatus = _selectedStatusFilter == 'All' || status == _selectedStatusFilter.toLowerCase();
        final matchesCategory = _selectedCategoryFilter == 'All' || category == _selectedCategoryFilter.toLowerCase();

        return matchesStatus && matchesCategory;
      }).toList();
    });
  }

  void _showRespondDialog(Map<String, dynamic> item) {
    final formKey = GlobalKey<FormState>();
    final responseController = TextEditingController(text: item['response'] as String? ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Respond to: ${item['first_name']} ${item['last_name']}'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Chip(
                  label: Text(item['category'] as String? ?? 'General Concern', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                ),
                const SizedBox(height: 8),
                const Text('Parent Question:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                Text(item['message'] as String? ?? '', style: const TextStyle(fontSize: 14)),
                const Divider(height: 24),
                TextFormField(
                  controller: responseController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Teacher Response',
                    border: OutlineInputBorder(),
                    hintText: 'Enter your response for the parent...',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => Validators.validateRequired(v, 'Teacher Response'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final user = await AuthRepositoryImpl().getCurrentUser();
                final teacherId = user?.id ?? 0;
                final rawId = item['id'] ?? item['doc_id']?.hashCode.abs() ?? 0;
                final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

                await _repository.respondToRequest(id, responseController.text.trim(), teacherId);

                if (mounted) {
                  Navigator.pop(context);
                  _loadRequests();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Response sent to parent!')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Send Response'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Clarifications'),
        actions: [
          IconButton(onPressed: _loadRequests, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRequests.isEmpty
                    ? const Center(child: Text('No clarification requests found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredRequests.length,
                        itemBuilder: (context, index) {
                          final item = _filteredRequests[index];
                          final isResponded = item['status'] == 'Responded';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${item['first_name']} ${item['last_name']} (${item['child_id']})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isResponded ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      item['status'] as String? ?? 'Pending',
                                      style: TextStyle(
                                        color: isResponded ? Colors.green : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Chip(
                                    label: Text(item['category'] as String? ?? 'General Concern', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Q: ${item['message']}', style: const TextStyle(fontSize: 14)),
                                  if (isResponded && item['response'] != null) ...[
                                    const SizedBox(height: 8),
                                    Text('Response: ${item['response']}', style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                                  ],
                                  const SizedBox(height: 4),
                                  Text('Date: ${item['created_at']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                              onTap: () => _showRespondDialog(item),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
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
                          label: Text(status, style: const TextStyle(fontSize: 11)),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedStatusFilter = status;
                                _applyFilters();
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
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.category, size: 18),
              const SizedBox(width: 8),
              const Text('Category:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categoryFilters.map((cat) {
                      final isSelected = _selectedCategoryFilter == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(cat, style: const TextStyle(fontSize: 11)),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategoryFilter = cat;
                                _applyFilters();
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
        ],
      ),
    );
  }
}
