import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:math';

import '../../../core/database/database_helper.dart';
import '../data/child_repository.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/data/auth_repository_impl.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/terms_privacy_dialog.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

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

  late TextEditingController _childIdController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _birthDateController;
  late TextEditingController _ageController;
  late TextEditingController _addressController;
  late TextEditingController _parentNameController;
  late TextEditingController _teacherNameController;

  String _selectedGender = 'Male';
  String? _selectedAffix;
  UserModel? _selectedParent;
  UserModel? _currentTeacher;
  List<UserModel> _parents = [];
  String? _parentLoadError;
  bool _isLoadingParents = true;
  bool _isEditMode = false;
  bool _agreedToPrivacyConsent = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.child != null;

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
          .get();
      parentUsers = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .where(
            (user) =>
                user.role == UserRole.parent &&
                user.status.toLowerCase() == 'active',
          )
          .toList();
    } catch (e) {
      _parentLoadError = e.toString();
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
    if (_parentNameController.text.isNotEmpty) {
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
      _selectedParent = selectedParent;
      _isLoadingParents = false;
      _parentLoadError = parentUsers.isEmpty ? _parentLoadError : null;
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
        final age = DateTime.now().year - picked.year;
        _ageController.text = age.toString();
      });
      _birthDateFieldKey.currentState?.didChange(_birthDateController.text);
    }
  }

  void _saveForm() async {
    if (_isSaving) return;
    if (_formKey.currentState!.validate()) {
      if (_selectedParent == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a parent/guardian account'),
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

      final childName =
          "${_firstNameController.text} ${_lastNameController.text}";

      final confirmed = await ConfirmationDialog.show(
        context: context,
        title: _isEditMode
            ? 'Confirm Child–Parent Update'
            : 'Confirm Child–Parent Link',
        message: _isEditMode
            ? 'Save the updated child profile and parent link for $childName?'
            : 'Link $childName to parent ${_selectedParent!.name}?',
        confirmLabel: _isEditMode ? 'Save Update' : 'Link Child',
        confirmColor: Colors.green,
        icon: Icons.link,
      );
      if (!confirmed) return;

      if (!mounted) return;
      setState(() => _isSaving = true);

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
        parentName: _selectedParent!.name,
        teacherName: _isEditMode && _currentTeacher?.role != UserRole.teacher
            ? widget.child!.teacherName
            : _teacherNameController.text.trim(),
        parentUid: _selectedParent!.uid,
        teacherUid: _isEditMode && _currentTeacher?.role != UserRole.teacher
            ? widget.child!.teacherUid
            : _currentTeacher?.uid ?? widget.child?.teacherUid,
        updatedAt: DateTime.now().toIso8601String(),
      );

      try {
        if (_isEditMode) {
          await _repository.updateChild(child);
        } else {
          await _repository.addChild(child);
        }

        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Child updated successfully'
                  : 'Child registered successfully',
            ),
          ),
        );
      } catch (error) {
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

  @override
  void dispose() {
    _childIdController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _parentNameController.dispose();
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
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final fields = [
                    TextFormField(
                      controller: _firstNameController,
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
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (v) => Validators.validateRequired(v, 'Address'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserModel>(
                key: ValueKey(
                  _selectedParent?.uid ?? _parentNameController.text,
                ),
                initialValue: _selectedParent,
                decoration: InputDecoration(
                  labelText: 'Parent/Guardian Name',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.family_restroom),
                  helperText: _isLoadingParents
                      ? 'Loading parent accounts...'
                      : _parents.isEmpty
                      ? _parentLoadError == null
                            ? 'No active parent accounts found. Add one in User Management first.'
                            : 'Could not load Firebase parents. Check Firestore rules or connection.'
                      : 'Choose from registered parent accounts',
                ),
                hint: Text(
                  _isLoadingParents
                      ? 'Loading parents...'
                      : 'Select parent/guardian',
                ),
                items: _parents
                    .map(
                      (parent) => DropdownMenuItem<UserModel>(
                        value: parent,
                        child: Text('${parent.name} (${parent.email})'),
                      ),
                    )
                    .toList(),
                selectedItemBuilder: (context) =>
                    _parents.map((parent) => Text(parent.name)).toList(),
                onChanged: _parents.isEmpty
                    ? null
                    : (parent) {
                        setState(() {
                          _selectedParent = parent;
                          _parentNameController.text = parent?.name ?? '';
                        });
                      },
                validator: (value) {
                  if (_parents.isEmpty) return 'No parent accounts available';
                  return value == null ? 'Parent selection is required' : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _teacherNameController,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Teacher/ECCD Worker Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school),
                ),
                validator: (v) =>
                    Validators.validatePersonName(v, 'Teacher name'),
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
}
