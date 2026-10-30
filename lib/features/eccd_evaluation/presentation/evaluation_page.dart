import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/evaluation_repository.dart';
import '../domain/evaluation_model.dart';

class EvaluationPage extends StatefulWidget {
  const EvaluationPage({super.key});
  @override
  State<EvaluationPage> createState() => _EvaluationPageState();
}

class _EvaluationPageState extends State<EvaluationPage> {
  final EvaluationRepository _repository = EvaluationRepositoryImpl();
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();
  final _domains = const [
    'Gross Motor',
    'Fine Motor',
    'Self-Help',
    'Language',
    'Cognitive',
    'Social-Emotional',
  ];
  List<ChildModel> _children = [];
  ChildModel? _selectedChild;
  String _selectedDomain = 'Gross Motor';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    final teacher = await AuthRepositoryImpl().getCurrentUser();
    final children = teacher == null
        ? <ChildModel>[]
        : await DatabaseHelper.instance.readChildrenByTeacher(teacher.uid);
    if (!mounted) {
      return;
    }
    setState(() {
      _children = children;
      _selectedChild = children.isEmpty ? null : children.first;
      _isLoading = false;
    });
  }

  Future<void> _saveEvaluation() async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        _selectedChild == null) {
      return;
    }
    final now = DateTime.now();
    await _repository.addEvaluation(
      EvaluationModel(
        childId: _selectedChild!.childId,
        domain: _selectedDomain,
        score: 0,
        remarks: _remarksController.text.trim(),
        evaluationDate: DateFormat('yyyy-MM-dd').format(now),
        updatedAt: now.toIso8601String(),
      ),
    );
    if (!mounted) return;
    _remarksController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Evaluation saved successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF7FBFF)),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _hero(isPhone),
                          const SizedBox(height: 24),
                          Container(
                            padding: EdgeInsets.all(isPhone ? 18 : 28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x100F2D52),
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _section(
                                  Icons.person_rounded,
                                  'Select Child',
                                  'Choose the child to evaluate.',
                                  BrandColors.sky,
                                  compact: isPhone,
                                ),
                                const SizedBox(height: 14),
                                DropdownButtonFormField<ChildModel>(
                                  initialValue: _selectedChild,
                                  isExpanded: true,
                                  decoration: _input(
                                    'Select Child',
                                    Icons.person,
                                  ),
                                  items: _children
                                      .map(
                                        (child) => DropdownMenuItem(
                                          value: child,
                                          child: Text(
                                            '${child.firstName} ${child.lastName}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (child) =>
                                      setState(() => _selectedChild = child),
                                ),
                                const SizedBox(height: 24),
                                _section(
                                  Icons.account_tree_rounded,
                                  'Development Domain',
                                  'Select the developmental domain.',
                                  BrandColors.green,
                                  compact: isPhone,
                                ),
                                const SizedBox(height: 14),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedDomain,
                                  decoration: _input(
                                    'Development Domain',
                                    Icons.account_tree_rounded,
                                  ),
                                  items: _domains
                                      .map(
                                        (domain) => DropdownMenuItem(
                                          value: domain,
                                          child: Text(domain),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (domain) =>
                                      setState(() => _selectedDomain = domain!),
                                ),
                                const SizedBox(height: 24),
                                _section(
                                  Icons.chat_bubble_rounded,
                                  'Remarks',
                                  'Add remarks or observations about the child’s progress.',
                                  BrandColors.sunshine,
                                  compact: isPhone,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _remarksController,
                                  maxLines: 4,
                                  maxLength: 500,
                                  decoration: _input(
                                    'Enter remarks...',
                                    Icons.comment_outlined,
                                  ).copyWith(alignLabelWithHint: true),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Remarks are required'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _saveEvaluation,
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text('Save Evaluation'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(0, 64),
                                    backgroundColor: const Color(0xFF1687F5),
                                    foregroundColor: Colors.white,
                                    textStyle: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _hero(bool isPhone) => Container(
    height: isPhone ? 188 : 174,
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
              widthFactor: isPhone ? 1 : .48,
              heightFactor: 1,
              child: Image.asset(
                'assets/images/evaluation_hero.png',
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
          left: isPhone ? 24 : 32,
          top: isPhone ? 28 : 38,
          right: isPhone ? 24 : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ECCD Evaluation',
                style: TextStyle(
                  fontSize: isPhone ? 28 : 34,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF102A72),
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Record and assess the child’s developmental progress.',
                style: TextStyle(fontSize: 15, color: Color(0xFF54769B)),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  InputDecoration _input(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: BrandColors.navy),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );
  Widget _section(
    IconData icon,
    String title,
    String subtitle,
    Color color, {
    required bool compact,
  }) => Row(
    children: [
      Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: color),
      ),
      SizedBox(width: compact ? 14 : 18),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: compact ? 18 : 20,
                color: Color(0xFF102A72),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    ],
  );
}
