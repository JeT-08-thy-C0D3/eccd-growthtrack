import 'package:flutter/material.dart';
import '../../../shared/models/child_model.dart';
import '../data/evaluation_repository.dart';

class EvaluationHistoryPage extends StatefulWidget {
  final ChildModel child;
  const EvaluationHistoryPage({super.key, required this.child});

  @override
  State<EvaluationHistoryPage> createState() => _EvaluationHistoryPageState();
}

class _EvaluationHistoryPageState extends State<EvaluationHistoryPage> {
  final EvaluationRepository _repository = EvaluationRepositoryImpl();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allHistory = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  String _searchQuery = '';
  String _selectedDomainFilter = 'All';
  String _sortBy = 'Date Newest First';
  bool _isLoading = true;

  final List<String> _domains = [
    'All',
    'Gross Motor',
    'Fine Motor',
    'Self-Help',
    'Language',
    'Cognitive',
    'Social-Emotional',
  ];

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
        final domain = (record['domain'] as String? ?? '').toLowerCase();
        final remarks = (record['remarks'] as String? ?? '').toLowerCase();
        final date = (record['evaluation_date'] as String? ?? '').toLowerCase();
        final childName = "${widget.child.firstName} ${widget.child.lastName}".toLowerCase();
        final childId = widget.child.childId.toLowerCase();

        final matchesSearch = domain.contains(q) || remarks.contains(q) || date.contains(q) || childName.contains(q) || childId.contains(q);
        final matchesDomain = _selectedDomainFilter == 'All' ||
            domain.toLowerCase() == _selectedDomainFilter.toLowerCase();

        return matchesSearch && matchesDomain;
      }).toList();

      _filteredHistory.sort((a, b) {
        final dateA = (a['evaluation_date'] as String? ?? '');
        final dateB = (b['evaluation_date'] as String? ?? '');
        switch (_sortBy) {
          case 'Date Oldest First':
            return dateA.compareTo(dateB);
          case 'Domain A-Z':
            return (a['domain'] as String? ?? '').compareTo(b['domain'] as String? ?? '');
          case 'Date Newest First':
          default:
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
        title: Text('Evaluation History: ${widget.child.firstName} (${widget.child.childId})'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search evaluations by Domain, Remarks, or Date...',
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
                    ? const Center(child: Text('No matching evaluations found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredHistory.length,
                        itemBuilder: (context, index) {
                          final record = _filteredHistory[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        record['domain'],
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      Text(
                                        record['evaluation_date'],
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                  Row(
                                    children: [
                                      const Text('Score: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text('${record['score']} / 4 pts'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('Remarks:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(record['remarks'] ?? 'No remarks'),
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

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 18),
          const SizedBox(width: 8),
          const Text('Domain:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _domains.map((domain) {
                  final isSelected = _selectedDomainFilter == domain;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(domain == 'All' ? 'All Domains' : domain, style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedDomainFilter = domain;
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
            items: ['Date Newest First', 'Date Oldest First', 'Domain A-Z']
                .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
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
