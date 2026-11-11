import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'dart:math';

import '../../../core/database/database_helper.dart';
import '../../../core/network/connectivity_service.dart';
import '../../admin/data/repositories/user_repository_impl.dart';
import '../../admin/domain/repositories/user_repository.dart';
import '../data/child_repository.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/terms_privacy_dialog.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../rfid/rfid_verification_dialog.dart';

class ChildRegistrationPage extends StatefulWidget {
  final ChildModel? child; // If provided, we are in Edit mode
  const ChildRegistrationPage({super.key, this.child});

  @override
  State<ChildRegistrationPage> createState() => _ChildRegistrationPageState();
}

class _ChildRegistrationPageState extends State<ChildRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _birthDateFieldKey = GlobalKey<FormFieldState<String>>();
  final ChildRepository _repository = ChildRepositoryImpl();
  final UserRepository _userRepository = UserRepositoryImpl();
  final ConnectivityService _connectivity = ConnectivityService();

  static const _defaultParentPassword = 'Eccd123@';

  late TextEditingController _childIdController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _birthDateController;
  late TextEditingController _ageController;
  late TextEditingController _addressController;
  late TextEditingController _parentNameController;
  late TextEditingController _parentEmailController;
  late TextEditingController _teacherNameController;

  String _selectedGender = 'Male';
  String? _selectedAffix;
  UserModel? _currentTeacher;
  List<UserModel> _parents = [];
  bool _isEditMode = false;
  bool _agreedToPrivacyConsent = false;
  bool _isSaving = false;
  late ChildModel _rfidChild;

  bool get _canManageRfid =>
      _currentTeacher?.role == UserRole.teacher ||
      _currentTeacher?.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.child != null;
    _rfidChild =
        widget.child ??
        ChildModel(
          childId: '',
          firstName: '',
          lastName: '',
          birthDate: '',
          age: 0,
          gender: '',
          address: '',
          parentName: '',
          teacherName: '',
          updatedAt: '',
        );
    // The original registration already required and captured consent. Editing
    // an existing profile should not force the teacher to re-complete it.
    _agreedToPrivacyConsent = _isEditMode;

    _childIdController = TextEditingController(
      text: _isEditMode ? widget.child!.childId : _generateChildId(),
    );
    _firstNameController = TextEditingController(
      text: _isEditMode ? widget.child!.firstName : '',
    );
    _lastNameController = TextEditingController(
      text: _isEditMode ? widget.child!.lastName : '',
    );
    _selectedAffix = _isEditMode ? widget.child!.affix : null;
    _birthDateController = TextEditingController(
      text: _isEditMode ? widget.child!.birthDate : '',
    );
    _ageController = TextEditingController(
      text: _isEditMode ? widget.child!.age.toString() : '',
    );
    _addressController = TextEditingController(
      text: _isEditMode ? widget.child!.address : '',
    );
    _parentNameController = TextEditingController(
      text: _isEditMode ? widget.child!.parentName : '',
    );
    _parentEmailController = TextEditingController();
    _teacherNameController = TextEditingController(
      text: _isEditMode ? widget.child!.teacherName : '',
    );

    _loadParents();

    if (_isEditMode) _selectedGender = widget.child!.gender;
    _loadCurrentTeacher();
  }

  Future<void> _loadParents() async {
    List<UserModel> parentUsers = [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .where('status', isEqualTo: 'active')
          .get();
      parentUsers = snapshot.docs
          .map(
            (doc) => UserModel.fromMap({
              ...doc.data(),
              // A link must always use the Firebase Auth/profile document ID.
              // Legacy `uid` fields can be stale and make a linked child
              // invisible to the actual parent account.
              'uid': doc.id,
            }),
          )
          .where(
            (user) =>
                user.role == UserRole.parent &&
                user.status.toLowerCase() == 'active',
          )
          .toList();
    } catch (_) {
      final allUsers = await DatabaseHelper.instance.readAllUsers();
      parentUsers = allUsers
          .where(
            (user) =>
                user.role == UserRole.parent &&
                user.status.toLowerCase() == 'active',
          )
          .toList();
    }

    parentUsers.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    UserModel? selectedParent;
    final linkedParentUid = widget.child?.parentUid?.trim() ?? '';
    if (linkedParentUid.isNotEmpty) {
      for (final parent in parentUsers) {
        if (parent.uid == linkedParentUid) {
          selectedParent = parent;
          break;
        }
      }
    }
    if (selectedParent == null && _parentNameController.text.isNotEmpty) {
      for (final parent in parentUsers) {
        if (parent.name.toLowerCase() ==
            _parentNameController.text.toLowerCase()) {
          selectedParent = parent;
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _parents = parentUsers;
      if (selectedParent != null) {
        _parentNameController.text = selectedParent.name;
        _parentEmailController.text = selectedParent.email;
      }
    });
  }

  Future<void> _loadCurrentTeacher() async {
    final user = await AuthRepositoryImpl().getCurrentUser();
    if (user != null) {
      if (!mounted) return;
      setState(() {
        _currentTeacher = user;
        // A teacher owns new child assignments. When a parent edits one of
        // several linked children, keep the original teacher assignment.
        if (!_isEditMode && user.role == UserRole.teacher) {
          _teacherNameController.text = user.name;
        }
      });
    }
  }

  String _generateChildId() {
    final random = Random();
    final year = DateTime.now().year.toString();
    final id = random.nextInt(9000) + 1000;
    return 'ECCD-$year-$id';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _isEditMode
          ? DateTime.tryParse(widget.child!.birthDate) ?? DateTime.now()
          : DateTime.now().subtract(const Duration(days: 365 * 3)),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        final now = DateTime.now();
        var age = now.year - picked.year;
        if (now.month < picked.month ||
            (now.month == picked.month && now.day < picked.day)) {
          age--;
        }
        _ageController.text = age.toString();
      });
      _birthDateFieldKey.currentState?.didChange(_birthDateController.text);
    }
  }

  String? _validateParentFullName(String? value) {
    final basicError = Validators.validatePersonName(
      value,
      'Parent/guardian name',
    );
    if (basicError != null) return basicError;
    final wordCount = value!.trim().split(RegExp(r'\s+')).length;
    return wordCount < 2
        ? 'Enter the parent/guardian\'s first and last name'
        : null;
  }

  String _normalizedName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  UserModel? _parentForEmail(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    for (final parent in _parents) {
      if (parent.email.trim().toLowerCase() == normalizedEmail) return parent;
    }
    return null;
  }

  Future<UserModel> _createParentAccount({
    required String name,
    required String email,
  }) async {
    if (!await _connectivity.isOnline) {
      throw StateError(
        'Connect to the internet to create and link a parent account.',
      );
    }

    final now = DateTime.now().toIso8601String();
    final parent = await _userRepository.createUser(
      UserModel(
        uid: 'pending-parent-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        email: email,
        password: _defaultParentPassword,
        role: UserRole.parent,
        status: 'active',
        createdAt: now,
        updatedAt: now,
        termsAcceptedAt: now,
      ),
    );
    if (mounted) {
      setState(() {
        _parents = [
          ..._parents,
          parent,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });
    }
    return parent;
  }

  void _saveForm() async {
    if (_isSaving) return;
    if (_formKey.currentState!.validate()) {
      final hasDuplicateName = await _hasDuplicateName();
      if (!mounted) return;
      if (hasDuplicateName) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A child with the same first and last name is already registered.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final parentName = _parentNameController.text.trim();
      final parentEmail = _parentEmailController.text.trim().toLowerCase();
      final existingParent = _parentForEmail(parentEmail);
      if (existingParent != null &&
          _normalizedName(existingParent.name) != _normalizedName(parentName)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This email is already registered to ${existingParent.name}. Use the matching parent/guardian name.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!_agreedToPrivacyConsent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Parent Data Privacy Consent under RA 10173/12199 is required',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final authenticatedTeacherUid = AuthRepositoryImpl().firebaseUserId;
      if (!_isEditMode &&
          (authenticatedTeacherUid == null ||
              authenticatedTeacherUid.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Teacher session is not ready. Please sign in again before linking a child.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final childName =
          "${_firstNameController.text} ${_lastNameController.text}";

      final confirmed = await ConfirmationDialog.show(
        context: context,
        title: _isEditMode
            ? 'Confirm Child–Parent Update'
            : 'Confirm Child–Parent Link',
        message: _isEditMode
            ? 'Save the updated child profile and parent link for $childName?'
            : existingParent == null
            ? 'Create a parent account for $parentName and link $childName to it? The default password is $_defaultParentPassword.'
            : 'Link $childName to parent ${existingParent.name}?',
        confirmLabel: _isEditMode ? 'Save Update' : 'Link Child',
        confirmColor: Colors.green,
        icon: Icons.link,
      );
      if (!confirmed) return;

      if (!mounted) return;
      setState(() => _isSaving = true);

      try {
        // A new parent account is deliberately created only after RFID
        // verification succeeds.  This keeps a cancelled/failed scan from
        // leaving either a child profile or a newly-created parent account.
        final provisionalParent = existingParent;
        final child = ChildModel(
          id: widget.child?.id,
          childId: _childIdController.text,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          affix: _selectedAffix,
          birthDate: _birthDateController.text,
          age: int.tryParse(_ageController.text) ?? 0,
          gender: _selectedGender,
          address: _addressController.text.trim(),
          parentName: provisionalParent?.name ?? parentName,
          teacherName: _isEditMode && _currentTeacher?.role != UserRole.teacher
              ? widget.child!.teacherName
              : (_currentTeacher?.name.trim().isNotEmpty == true
                    ? _currentTeacher!.name.trim()
                    : _teacherNameController.text.trim()),
          parentUid: provisionalParent?.uid,
          teacherUid: _isEditMode && _currentTeacher?.role != UserRole.teacher
              ? widget.child!.teacherUid
              : authenticatedTeacherUid ??
                    _currentTeacher?.uid ??
                    widget.child?.teacherUid,
          status: _isEditMode ? widget.child!.status : 'active',
          updatedAt: DateTime.now().toIso8601String(),
          rfidUid: _rfidChild.rfidUid,
          rfidVerified: _rfidChild.rfidVerified,
          rfidLinkedAt: _rfidChild.rfidLinkedAt,
        );

        if (_isEditMode) {
          await _repository.updateChild(child);
        } else {
          await _repository.addChild(child);
        }

        _rfidChild = child;
        if (!_isEditMode && mounted) {
          final verified = await showRfidVerificationDialog(
            context: context,
            child: child,
            repository: _repository,
          );
          if (verified == null) {
            await _repository.discardPendingChild(child);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Registration cancelled or RFID verification failed. No child profile was saved.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
          _rfidChild = verified;

          if (existingParent == null) {
            final linkedParent = await _createParentAccount(
              name: parentName,
              email: parentEmail,
            );
            final linkedChild = verified.copyWith(
              parentName: linkedParent.name,
              parentUid: linkedParent.uid,
              updatedAt: DateTime.now().toIso8601String(),
            );
            await _repository.updateChild(linkedChild);
            _rfidChild = linkedChild;
          }
        }

        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Child updated successfully'
                  : existingParent == null
                  ? 'Child registered and parent account created. Default password: $_defaultParentPassword'
                  : _rfidChild.rfidVerified
                  ? 'Child Registration and RFID Verification Successful'
                  : 'Child registered. RFID verification is pending.',
            ),
          ),
        );
      } catch (error) {
        // A later failure (for example, creating a new parent account) must
        // not leave a successfully-scanned child half-registered. Best effort
        // unlinking restores the record to a state the guarded discard method
        // is allowed to remove.
        if (!_isEditMode && _rfidChild.rfidVerified) {
          try {
            final unlinked = await _repository.unlinkRfidCard(_rfidChild);
            await _repository.discardPendingChild(unlinked);
            _rfidChild = unlinked;
          } catch (_) {
            // The original error is shown below. A retry-safe audit record
            // still exists, and no success message is ever shown.
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _hasDuplicateName() async {
    // See ChildRepository: a browser cannot perform the broad duplicate
    // preflight read under the teacher's scoped Firestore permissions.
    // The required field validation still runs before a link is saved.
    if (kIsWeb) return false;

    final firstName = _normalizeName(_firstNameController.text);
    final lastName = _normalizeName(_lastNameController.text);
    final currentChildId = widget.child?.childId;
    final teacherUid = AuthRepositoryImpl().firebaseUserId;
    final children = teacherUid == null
        ? const <ChildModel>[]
        : await DatabaseHelper.instance.readChildrenByTeacher(
            teacherUid,
            includeInactive: true,
          );
    return children.any(
      (child) =>
          child.childId != currentChildId &&
          _normalizeName(child.firstName) == firstName &&
          _normalizeName(child.lastName) == lastName,
    );
  }

  String _normalizeName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  @override
  void dispose() {
    _childIdController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _parentNameController.dispose();
    _parentEmailController.dispose();
    _teacherNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Child Profile' : 'Child Registration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _childIdController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Child ID (Auto-generated)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code),
                  fillColor: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              _buildRfidCard(),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fields = [
                    TextFormField(
                      controller: _firstNameController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          Validators.validatePersonName(v, 'First name'),
                    ),
                    TextFormField(
                      controller: _lastNameController,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          Validators.validatePersonName(v, 'Last name'),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAffix,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Affix (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Jr.', child: Text('Jr.')),
                        DropdownMenuItem(value: 'Sr.', child: Text('Sr.')),
                        DropdownMenuItem(value: 'II', child: Text('II')),
                        DropdownMenuItem(value: 'III', child: Text('III')),
                        DropdownMenuItem(value: 'IV', child: Text('IV')),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedAffix = value),
                    ),
                  ];
                  if (constraints.maxWidth < 620) {
                    return Column(
                      children: [
                        fields[0],
                        const SizedBox(height: 16),
                        fields[1],
                        const SizedBox(height: 16),
                        fields[2],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: fields[0]),
                      const SizedBox(width: 16),
                      Expanded(child: fields[1]),
                      const SizedBox(width: 16),
                      SizedBox(width: 150, child: fields[2]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final birthDate = TextFormField(
                    key: _birthDateFieldKey,
                    controller: _birthDateController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    readOnly: true,
                    onTap: _selectDate,
                    decoration: const InputDecoration(
                      labelText: 'Birth Date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    validator: (v) =>
                        Validators.validateRequired(v, 'Birth date'),
                  );
                  final age = TextFormField(
                    controller: _ageController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        Validators.validateAge(v, min: 0, max: 12),
                  );
                  if (constraints.maxWidth < 420) {
                    return Column(
                      children: [birthDate, const SizedBox(height: 16), age],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 2, child: birthDate),
                      const SizedBox(width: 16),
                      Expanded(child: age),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                ),
                items: ['Male', 'Female']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedGender = val!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (v) => Validators.validateRequired(v, 'Address'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _parentNameController,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Parent/Guardian Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.family_restroom),
                ),
                validator: _validateParentFullName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _parentEmailController,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Parent/Guardian Gmail',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                  helperText: 'A new parent account uses the default password: Eccd123@',
                ),
                validator: Validators.validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _teacherNameController,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z. ]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Teacher/ECCD Worker Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school),
                ),
                validator: (v) =>
                    Validators.validateTeacherName(v, 'Teacher name'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _agreedToPrivacyConsent,
                    onChanged: (val) =>
                        setState(() => _agreedToPrivacyConsent = val ?? false),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => TermsPrivacyDialog.show(context),
                      child: const Text(
                        'Parent Data Privacy Consent (RA 10173 & RA 12199 Compliance)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isEditMode ? 'Update Profile' : 'Register Child',
                        style: const TextStyle(fontSize: 18),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRfidCard() {
    final verified = _rfidChild.rfidVerified;
    final uid = _rfidChild.rfidUid;
    return Card(
      color: verified ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  verified
                      ? Icons.verified_rounded
                      : Icons.pending_actions_rounded,
                  color: verified
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                Text(
                  verified ? 'RFID Verified' : 'Pending RFID Verification',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              uid == null || uid.isEmpty
                  ? 'No RFID card linked yet.'
                  : 'RFID UID: $uid',
            ),
            if (_isEditMode && _canManageRfid) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _verifyExistingChild,
                    icon: const Icon(Icons.contactless_rounded),
                    label: Text(
                      verified ? 'Replace RFID Card' : 'Link RFID Card',
                    ),
                  ),
                  if (verified)
                    TextButton.icon(
                      onPressed: _isSaving ? null : _unlinkRfidCard,
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('Unlink RFID Card'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _verifyExistingChild() async {
    final result = await showRfidVerificationDialog(
      context: context,
      child: _rfidChild,
      repository: _repository,
    );
    if (result != null && mounted) setState(() => _rfidChild = result);
  }

  Future<void> _unlinkRfidCard() async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Unlink RFID card?',
      message: 'This child will remain registered but cannot use the removed card for attendance.',
      confirmLabel: 'Unlink',
      confirmColor: Colors.red,
      icon: Icons.link_off_rounded,
    );
    if (!confirmed) return;
    try {
      final updated = await _repository.unlinkRfidCard(_rfidChild);
      if (mounted) setState(() => _rfidChild = updated);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
    }
  }
}
