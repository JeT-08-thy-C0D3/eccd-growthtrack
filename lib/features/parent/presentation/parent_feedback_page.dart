import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_helper.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/widgets/brand_widgets.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../data/parent_feedback_repository.dart';
import '../domain/parent_feedback_model.dart';

class ParentFeedbackPage extends StatefulWidget {
  final ParentFeedbackModel? feedback;
  const ParentFeedbackPage({super.key, this.feedback});

  @override
  State<ParentFeedbackPage> createState() => _ParentFeedbackPageState();
}

class _ParentFeedbackPageState extends State<ParentFeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ParentFeedbackRepositoryImpl();

  ChildModel? _selectedChild;
  List<ChildModel> _children = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final _observationController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedAssistance = 'Independent';

  final List<String> _assistanceLevels = [
    'Independent',
    'Minimal Assistance',
    'Moderate Assistance',
    'Full Assistance',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.feedback != null) {
      _observationController.text = widget.feedback!.parentObservation;
      _notesController.text = widget.feedback!.notes;
      _selectedAssistance = widget.feedback!.assistanceLevel;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = await AuthRepositoryImpl().getCurrentUser();
      if (user != null) {
        final children = await DatabaseHelper.instance.readChildrenByParent(
          user.uid,
        );
        if (!mounted) return;
        setState(() {
          _children = children;
          if (widget.feedback != null) {
            _selectedChild = children.firstWhere(
              (c) => c.childId == widget.feedback!.childId,
            );
          } else if (_children.isNotEmpty) {
            _selectedChild = _children.first;
          }
          _isLoading = false;
        });
        return;
      }
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  void _saveFeedback() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedChild == null) return;

      if (widget.feedback != null) {
        final confirmed = await ConfirmationDialog.showEdit(
          context: context,
          itemName: 'Feedback for ${_selectedChild!.firstName}',
        );
        if (!confirmed) return;
      }

      setState(() => _isSaving = true);

      final user = await AuthRepositoryImpl().getCurrentUser();
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final localUsers = await DatabaseHelper.instance.readAllUsers();
      int parentId = user?.id ?? 0;
      for (final localUser in localUsers) {
        if (localUser.uid == user?.uid && localUser.id != null) {
          parentId = localUser.id!;
          break;
        }
      }

      final feedback = ParentFeedbackModel(
        id: widget.feedback?.id,
        childId: _selectedChild!.childId,
        parentId: parentId,
        parentObservation: _observationController.text.trim(),
        assistanceLevel: _selectedAssistance,
        notes: _notesController.text.trim(),
        submissionDate: widget.feedback?.submissionDate ?? now,
        updatedAt: now,
        isSynced: false,
      );

      if (widget.feedback != null) {
        await _repository.updateFeedback(feedback);
      } else {
        await _repository.submitFeedback(feedback);
      }

      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.feedback != null
                  ? 'Feedback updated!'
                  : 'Feedback submitted!',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FCFF),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FeedbackHero(isEditing: widget.feedback != null),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: BrandColors.sky.withValues(alpha: .08),
                                blurRadius: 28,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<ChildModel>(
                                initialValue: _selectedChild,
                                decoration: _feedbackDecoration(
                                  labelText: 'Select Child',
                                  hintText: 'Choose a child...',
                                  icon: Icons.person_outline_rounded,
                                ),
                                items: _children
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(
                                          "${c.firstName} ${c.lastName}",
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: widget.feedback != null
                                    ? null
                                    : (val) =>
                                          setState(() => _selectedChild = val),
                              ),
                              const SizedBox(height: 26),
                              TextFormField(
                                controller: _observationController,
                                maxLines: 3,
                                decoration: _feedbackDecoration(
                                  labelText: 'Your Observation',
                                  hintText: 'What did you observe about your child today?',
                                  icon: Icons.visibility_outlined,
                                ),
                                validator: (value) =>
                                    value!.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 26),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedAssistance,
                                decoration: _feedbackDecoration(
                                  labelText: 'Assistance Level',
                                  hintText: 'Select assistance level...',
                                  icon: Icons.help_outline_rounded,
                                ),
                                items: _assistanceLevels
                                    .map(
                                      (l) => DropdownMenuItem(
                                        value: l,
                                        child: Text(l),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedAssistance = val!),
                              ),
                              const SizedBox(height: 26),
                              TextFormField(
                                controller: _notesController,
                                maxLines: 4,
                                decoration: _feedbackDecoration(
                                  labelText: 'Additional Notes',
                                  hintText:
                                      'Any other details you want to share?',
                                  icon: Icons.description_outlined,
                                ),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                height: 65,
                                child: ElevatedButton.icon(
                                  onPressed: _isSaving ? null : _saveFeedback,
                                  icon: _isSaving
                                      ? const SizedBox.shrink()
                                      : const Icon(
                                          Icons.send_rounded,
                                          size: 27,
                                        ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1197F0),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  label: _isSaving
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : Text(
                                          widget.feedback != null
                                              ? 'Update Feedback'
                                              : 'Submit Feedback',
                                          style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w700,
                                          ),
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
    );
  }

  InputDecoration _feedbackDecoration({
    required String labelText,
    required String hintText,
    required IconData icon,
  }) => InputDecoration(
    labelText: labelText,
    hintText: hintText,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    prefixIcon: Icon(icon, color: const Color(0xFF38567F), size: 27),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    filled: true,
    fillColor: const Color(0xFFFEFEFF),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFFBBD2F2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFFBBD2F2)),
    ),
  );
}

class _FeedbackHero extends StatelessWidget {
  const _FeedbackHero({required this.isEditing});
  final bool isEditing;

  @override
  Widget build(BuildContext context) => Container(
    height: 190,
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFFEAF8FF), Color(0xFFD9F0FF)],
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          right: 27,
          bottom: -50,
          child: Icon(
            Icons.family_restroom_rounded,
            size: 230,
            color: const Color(0xFFFF8B99).withValues(alpha: .75),
          ),
        ),
        Positioned(
          right: 188,
          bottom: -14,
          child: Icon(
            Icons.spa_rounded,
            size: 115,
            color: BrandColors.green.withValues(alpha: .52),
          ),
        ),
        Positioned(
          right: 182,
          top: 20,
          child: const Icon(
            Icons.favorite_rounded,
            color: Color(0xFFFF7E96),
            size: 43,
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
                Icons.chat_bubble_rounded,
                size: 51,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 25),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Edit Feedback' : 'Parent Feedback',
                    style: const TextStyle(
                      color: Color(0xFF07135B),
                      fontSize: 39,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Share your observations and insights about your child's learning\nand development.",
                    style: TextStyle(
                      color: Color(0xFF156BC0),
                      fontSize: 17,
                      height: 1.35,
                    ),
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
