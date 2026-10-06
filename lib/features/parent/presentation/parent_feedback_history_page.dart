import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/parent_feedback_repository.dart';
import '../domain/parent_feedback_model.dart';
import 'parent_feedback_page.dart';

class ParentFeedbackHistoryPage extends StatefulWidget {
  const ParentFeedbackHistoryPage({super.key});

  @override
  State<ParentFeedbackHistoryPage> createState() => _ParentFeedbackHistoryPageState();
}

class _ParentFeedbackHistoryPageState extends State<ParentFeedbackHistoryPage> {
  final _repository = ParentFeedbackRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();
  
  List<ParentFeedbackModel> _allHistory = [];
  List<ParentFeedbackModel> _filteredHistory = [];
  List<ChildModel> _children = [];
  ChildModel? _selectedFilterChild; // null means 'All Children'
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = await AuthRepositoryImpl().getCurrentUser();
    if (user != null) {
      _children = await DatabaseHelper.instance.readChildrenByParent(user.uid);
      await _loadHistory();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    List<ParentFeedbackModel> combined = [];
    if (_children.isNotEmpty) {
      for (final child in _children) {
        final data = await _repository.getFeedbackHistory(child.childId);
        combined.addAll(data);
      }
    }
    
    // Sort by submission date (newest first)
    combined.sort((a, b) => b.submissionDate.compareTo(a.submissionDate));

    setState(() {
      _allHistory = combined;
      _applyFilterAndSearch();
      _isLoading = false;
    });
  }

  void _applyFilterAndSearch() {
    setState(() {
      final q = _searchQuery.toLowerCase();
      _filteredHistory = _allHistory.where((item) {
        final matchesChild = _selectedFilterChild == null || item.childId == _selectedFilterChild!.childId;
        final obs = item.parentObservation.toLowerCase();
        final notes = item.notes.toLowerCase();
        final level = item.assistanceLevel.toLowerCase();
        final date = item.submissionDate.toLowerCase();

        final matchesSearch = obs.contains(q) || notes.contains(q) || level.contains(q) || date.contains(q);

        return matchesChild && matchesSearch;
      }).toList();
    });
  }

  void _deleteFeedback(ParentFeedbackModel item) async {
    final confirmed = await ConfirmationDialog.showDelete(
      context: context,
      itemName: 'Feedback submission from ${item.submissionDate}',
    );

    if (confirmed) {
      await _repository.deleteFeedback(item.id!);
      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback deleted successfully')),
        );
      }
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
      appBar: AppBar(title: const Text('Feedback History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Search observation, notes, or date...',
                    leading: const Icon(Icons.search),
                    onChanged: (val) {
                      _searchQuery = val;
                      _applyFilterAndSearch();
                    },
                  ),
                ),
                if (_children.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: DropdownButtonFormField<ChildModel?>(
                      value: _selectedFilterChild,
                      decoration: const InputDecoration(
                        labelText: 'Filter by Child',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.filter_list),
                      ),
                      items: [
                        const DropdownMenuItem<ChildModel?>(
                          value: null,
                          child: Text('All Children'),
                        ),
                        ..._children.map(
                          (c) => DropdownMenuItem<ChildModel?>(
                            value: c,
                            child: Text("${c.firstName} ${c.lastName}"),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedFilterChild = val;
                          _applyFilterAndSearch();
                        });
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: _filteredHistory.isEmpty
                      ? const Center(child: Text('No matching feedback records found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredHistory.length,
                          itemBuilder: (context, index) {
                            final item = _filteredHistory[index];
                            ChildModel? child;
                            for (final c in _children) {
                              if (c.childId == item.childId) {
                                child = c;
                                break;
                              }
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          child != null ? '${child.firstName} ${child.lastName}' : item.childId,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                              onPressed: () async {
                                                final result = await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (context) => ParentFeedbackPage(feedback: item)),
                                                );
                                                if (result == true) _loadHistory();
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                              onPressed: () => _deleteFeedback(item),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Text('Submitted on: ${item.submissionDate}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    const Divider(),
                                    _buildInfoText('Observation:', item.parentObservation),
                                    const SizedBox(height: 8),
                                    _buildInfoText('Assistance Level:', item.assistanceLevel, color: Colors.blue),
                                    if (item.notes.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _buildInfoText('Notes:', item.notes),
                                    ],
                                  ],
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

  Widget _buildInfoText(String label, String content, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        Text(content, style: TextStyle(fontSize: 14, color: color)),
      ],
    );
  }
}
