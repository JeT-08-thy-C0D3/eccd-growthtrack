import 'package:flutter/material.dart';

import '../../parent/data/clarification_repository.dart';
import '../../../core/utils/validators.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../../../shared/widgets/brand_widgets.dart';

class TeacherClarificationsPage extends StatefulWidget {
  const TeacherClarificationsPage({super.key});

  @override
  State<TeacherClarificationsPage> createState() =>
      _TeacherClarificationsPageState();
}

class _TeacherClarificationsPageState extends State<TeacherClarificationsPage> {
  final _repository = ClarificationRepositoryImpl();
  List<Map<String, dynamic>> _allRequests = [];
  List<Map<String, dynamic>> _filteredRequests = [];
  String _selectedStatusFilter = 'All';
  String _selectedCategoryFilter = 'All';
  bool _isLoading = true;
  String? _loadError;

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
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final data = await _repository.getAllRequestsWithChild().timeout(
        const Duration(seconds: 15),
      );
      if (!mounted) return;
      setState(() {
        _allRequests = data;
        _filteredRequests = _filterRequests(data);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError = 'Unable to load clarification requests. Check your connection and try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    setState(() => _filteredRequests = _filterRequests(_allRequests));
  }

  List<Map<String, dynamic>> _filterRequests(
    List<Map<String, dynamic>> items,
  ) => items.where((item) {
    final status = (item['status'] as String? ?? 'Pending').toLowerCase();
    final category = (item['category'] as String? ?? 'General Concern')
        .toLowerCase();
    final matchesStatus =
        _selectedStatusFilter == 'All' ||
        status == _selectedStatusFilter.toLowerCase();
    final matchesCategory =
        _selectedCategoryFilter == 'All' ||
        category == _selectedCategoryFilter.toLowerCase();
    return matchesStatus && matchesCategory;
  }).toList();

  void _showRespondDialog(Map<String, dynamic> item) {
    final formKey = GlobalKey<FormState>();
    final responseController = TextEditingController(
      text: item['response'] as String? ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Respond to: ${item['first_name']} ${item['last_name']}'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Chip(
                  label: Text(
                    item['category'] as String? ?? 'General Concern',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Parent Question:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  item['message'] as String? ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
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
                  validator: (v) => Validators.validateAppropriateText(
                    v,
                    'Teacher Response',
                    required: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final user = await AuthRepositoryImpl().getCurrentUser();
                final teacherId = user?.id ?? 0;
                final rawId = item['id'] ?? item['doc_id']?.hashCode.abs() ?? 0;
                final id = rawId is int
                    ? rawId
                    : int.tryParse(rawId.toString()) ?? 0;

                try {
                  await _repository.respondToRequest(
                    id,
                    responseController.text.trim(),
                    teacherId,
                    documentId: item['doc_id']?.toString(),
                  );
                  if (!mounted) return;
                  Navigator.of(this.context).pop();
                  await _loadRequests();
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Response saved. This request is now Responded.',
                      ),
                    ),
                  );
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Unable to save response: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Response'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Parent Clarifications'),
      ),
      body: Column(
        children: [
          _buildHero(isPhone),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: Colors.orange,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _loadRequests,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                : _filteredRequests.isEmpty
                ? const Center(child: Text('No clarification requests found.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredRequests.length,
                    itemBuilder: (context, index) {
                      final item = _filteredRequests[index];
                      final isResponded =
                          (item['status']?.toString() ?? '').toLowerCase() ==
                          'responded';
                      final response = item['response']?.toString().trim();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item['first_name']} ${item['last_name']} (${item['child_id']})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isResponded
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item['status'] as String? ?? 'Pending',
                                  style: TextStyle(
                                    color: isResponded
                                        ? Colors.green
                                        : Colors.orange,
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
                                label: Text(
                                  item['category'] as String? ??
                                      'General Concern',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: Colors.blue.withValues(
                                  alpha: 0.1,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Q: ${item['message']}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              if (isResponded &&
                                  response != null &&
                                  response.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Teacher response: $response',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'Date: ${item['created_at']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
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

  Widget _buildHero(bool isPhone) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
    child: Container(
      height: 188,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5FF), Color(0xFFF9FCFF)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: isPhone ? 1 : .47,
                heightFactor: 1,
                child: Image.asset(
                  'assets/images/clarifications_hero.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          if (isPhone)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xE6E8F5FF), Color(0x66F9FCFF)],
                  ),
                ),
              ),
            ),
          Positioned(
            left: isPhone ? 24 : 30,
            top: isPhone ? 28 : 36,
            right: isPhone ? 24 : null,
            child: Row(
              children: [
                const Icon(
                  Icons.forum_rounded,
                  color: BrandColors.sky,
                  size: 42,
                ),
                SizedBox(width: isPhone ? 14 : 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parent Clarifications',
                        style: TextStyle(
                          fontSize: isPhone ? 24 : 31,
                          color: Color(0xFF102A72),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'View and respond to parents’ questions, concerns, and clarifications.',
                        style: TextStyle(
                          color: Color(0xFF54769B),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 460
              ? constraints.maxWidth
              : (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: width,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStatusFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(Icons.filter_list),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                  ),
                  items: _statusFilters
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedStatusFilter = value);
                    _applyFilters();
                  },
                ),
              ),
              SizedBox(
                width: width,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                  ),
                  items: _categoryFilters
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedCategoryFilter = value);
                    _applyFilters();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
