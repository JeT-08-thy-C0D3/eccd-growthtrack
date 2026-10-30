import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../../core/utils/validators.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/clarification_repository.dart';
import '../domain/clarification_model.dart';

class ParentClarificationPage extends StatefulWidget {
  const ParentClarificationPage({super.key});

  @override
  State<ParentClarificationPage> createState() =>
      _ParentClarificationPageState();
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
    try {
      final user = await AuthRepositoryImpl().getCurrentUser();
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final children = kIsWeb
          ? await _readChildrenFromFirestore(user.uid, user.name)
          : await DatabaseHelper.instance.readChildrenByParent(user.uid);
      if (!mounted) return;
      if (children.isNotEmpty) {
        _children = children;
        _selectedChild = children.first;
        await _loadRequests();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load linked children: $error')),
      );
    }
  }

  Future<List<ChildModel>> _readChildrenFromFirestore(
    String parentUid,
    String parentName,
  ) async {
    final firestore = FirebaseFirestore.instance;
    try {
      var snapshot = await firestore
          .collection('children')
          .where('parent_uid', isEqualTo: parentUid)
          .get();
      if (snapshot.docs.isEmpty && parentName.trim().isNotEmpty) {
        snapshot = await firestore
            .collection('children')
            .where('parent_name', isEqualTo: parentName)
            .get();
      }
      return snapshot.docs
          .map((doc) => ChildModel.fromMap(doc.data()))
          .toList();
    } on FirebaseException catch (error) {
      throw error.message ?? 'Unable to read linked children from Firestore.';
    }
  }

  Future<void> _loadRequests() async {
    if (_selectedChild == null) return;
    final requests = await _repository.getRequestsByChild(
      _selectedChild!.childId,
    );
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

      try {
        await _repository.sendRequest(request);
        _messageController.clear();
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clarification request submitted to teacher!'),
          ),
        );
        _loadRequests();
      } catch (error) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to submit clarification request: $error'),
          ),
        );
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
    return Container(
      color: const Color(0xFFF8FCFF),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _children.isEmpty
          ? const Center(child: Text('No children linked to your account.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ClarificationHero(),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: Color(0xFFD7E5F5)),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(28.0),
                          child: Form(
                            key: _formKey,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Submit a Question to Teacher',
                                  style: TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    color: BrandColors.sky,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<ChildModel>(
                                  initialValue: _selectedChild,
                                  isExpanded: true,
                                  decoration: _fieldDecoration(
                                    labelText: 'Select Child',
                                    icon: Icons.person_outline_rounded,
                                  ),
                                  items: _children
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(
                                            "${c.firstName} ${c.lastName} (${c.childId})",
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedChild = val);
                                    _loadRequests();
                                  },
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedCategory,
                                  isExpanded: true,
                                  decoration: _fieldDecoration(
                                    labelText: 'Category',
                                    icon: Icons.group_outlined,
                                  ),
                                  items: _categories
                                      .map(
                                        (cat) => DropdownMenuItem(
                                          value: cat,
                                          child: Text(
                                            cat,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedCategory = val!),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _messageController,
                                  maxLines: 3,
                                  decoration: _fieldDecoration(
                                    labelText: 'Your Question / Clarification',
                                    hintText: 'Type your question or clarification details for the teacher...',
                                    icon: Icons.chat_bubble_outline_rounded,
                                    alignLabelWithHint: true,
                                  ),
                                  validator: (v) => Validators.validateRequired(
                                    v,
                                    'Question / Clarification',
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  height: 58,
                                  child: ElevatedButton.icon(
                                    onPressed: _isSaving
                                        ? null
                                        : _submitQuestion,
                                    icon: const Icon(Icons.send),
                                    label: Text(
                                      _isSaving
                                          ? 'Submitting...'
                                          : 'Submit Request',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      backgroundColor: const Color(0xFF1197F0),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            color: BrandColors.sky,
                            size: 29,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Request History (${_requests.length})',
                            style: const TextStyle(
                              color: Color(0xFF07135B),
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_requests.isEmpty)
                        const _RequestsEmptyState()
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      runSpacing: 6,
                                      children: [
                                        Chip(
                                          label: Text(
                                            item.category,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          backgroundColor: Colors.blue
                                              .withValues(alpha: 0.1),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isResponded
                                                ? Colors.green.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.orange.withValues(
                                                    alpha: 0.1,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            item.status,
                                            style: TextStyle(
                                              color: isResponded
                                                  ? Colors.green
                                                  : Colors.orange,
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
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Submitted: ${item.createdAt}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    if (isResponded &&
                                        item.response != null) ...[
                                      const Divider(height: 20),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.05,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.green.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Row(
                                              children: [
                                                Icon(
                                                  Icons.mark_chat_read,
                                                  size: 16,
                                                  color: Colors.green,
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Teacher Response:',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.response!,
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
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
              ),
            ),
    );
  }

  InputDecoration _fieldDecoration({
    required String labelText,
    required IconData icon,
    String? hintText,
    bool alignLabelWithHint = false,
  }) => InputDecoration(
    labelText: labelText,
    hintText: hintText,
    alignLabelWithHint: alignLabelWithHint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    prefixIcon: Icon(icon, color: const Color(0xFF38567F)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFD0DFF2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFD0DFF2)),
    ),
  );
}

class _ClarificationHero extends StatelessWidget {
  const _ClarificationHero();
  @override
  Widget build(BuildContext context) => Container(
    height: 190,
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFFEAF8FF), Color(0xFFD8F0FF)],
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          right: 22,
          bottom: -48,
          child: Icon(
            Icons.family_restroom_rounded,
            size: 228,
            color: const Color(0xFFFF8796).withValues(alpha: .76),
          ),
        ),
        Positioned(
          right: 192,
          bottom: -12,
          child: Icon(
            Icons.spa_rounded,
            size: 115,
            color: BrandColors.green.withValues(alpha: .55),
          ),
        ),
        Positioned(
          right: 188,
          top: 17,
          child: const Icon(
            Icons.question_mark_rounded,
            color: BrandColors.sunshine,
            size: 54,
          ),
        ),
        Row(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF168FEA),
                borderRadius: BorderRadius.circular(23),
              ),
              child: const Icon(
                Icons.question_answer_rounded,
                size: 52,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 25),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clarification Requests',
                    style: TextStyle(
                      color: Color(0xFF07135B),
                      fontSize: 39,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Ask questions and get support from your child's teacher.",
                    style: TextStyle(color: Color(0xFF156BC0), fontSize: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _RequestsEmptyState extends StatelessWidget {
  const _RequestsEmptyState();
  @override
  Widget build(BuildContext context) => Container(
    height: 146,
    padding: const EdgeInsets.symmetric(horizontal: 36),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.quiz_rounded,
          color: BrandColors.sky.withValues(alpha: .75),
          size: 73,
        ),
        const SizedBox(width: 30),
        const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No clarification requests submitted yet.',
              style: TextStyle(
                color: Color(0xFF07135B),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Your submitted questions and responses\nwill appear here.',
              style: TextStyle(color: Color(0xFF60749C), fontSize: 15),
            ),
          ],
        ),
      ],
    ),
  );
}
