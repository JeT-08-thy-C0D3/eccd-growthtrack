import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/database/database_helper.dart';
import '../data/child_repository.dart';
import '../../../shared/models/child_model.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/data/auth_repository_impl.dart';

class ChildRegistrationPage extends StatefulWidget {
  final ChildModel? child; // If provided, we are in Edit mode
  const ChildRegistrationPage({super.key, this.child});

  @override
  State<ChildRegistrationPage> createState() => _ChildRegistrationPageState();
}

class _ChildRegistrationPageState extends State<ChildRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
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
  UserModel? _selectedParent;
  List<UserModel> _parents = [];
  String? _parentLoadError;
  bool _isLoadingParents = true;
  bool _isEditMode = false;

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

    if (_isEditMode) {
      _selectedGender = widget.child!.gender;
    } else {
      _loadCurrentTeacher();
    }
  }

  Future<void> _loadParents() async {
    List<UserModel> parentUsers = [];

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
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
      // If Firebase is temporarily unavailable, fall back to the local cache.
      final allUsers = await DatabaseHelper.instance.readAllUsers();
      parentUsers = allUsers
          .where(
            (user) =>
                user.role == UserRole.parent &&
                user.status.toLowerCase() == 'active',
          )
          .toList();
    }

    parentUsers
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

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
        _teacherNameController.text = user.name;
      });
    }
  }

  String _generateChildId() {
    final random = Random();
    final year = DateTime.now().year.toString();
    final id = random.nextInt(9000) + 1000; // 4 digit random
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
    }
  }

  void _saveForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedParent == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a parent/guardian account'),
          ),
        );
        return;
      }

      final child = ChildModel(
        id: widget.child?.id,
        childId: _childIdController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        birthDate: _birthDateController.text,
        age: int.tryParse(_ageController.text) ?? 0,
        gender: _selectedGender,
        address: _addressController.text,
        parentName: _selectedParent!.name,
        teacherName: _teacherNameController.text,
        updatedAt: DateTime.now().toIso8601String(),
      );

      if (_isEditMode) {
        await _repository.updateChild(child);
      } else {
        await _repository.addChild(child);
      }

      if (mounted) {
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
      appBar: AppBar(title: Text(_isEditMode ? 'Edit Child Profile' : 'Child Registration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _birthDateController,
                      readOnly: true,
                      onTap: _selectDate,
                      decoration: const InputDecoration(
                        labelText: 'Birth Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
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
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserModel>(
                key: ValueKey(_selectedParent?.uid ?? _parentNameController.text),
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
                  return value == null ? 'Required' : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _teacherNameController,
                decoration: const InputDecoration(
                  labelText: 'Teacher/ECCD Worker Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(
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
