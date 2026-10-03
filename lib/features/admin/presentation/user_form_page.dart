import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/user_model.dart';
import '../domain/repositories/user_repository.dart';
import '../data/repositories/user_repository_impl.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/terms_privacy_dialog.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

class UserFormPage extends StatefulWidget {
  final UserModel? user;
  const UserFormPage({super.key, this.user});

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  final UserRepository _repository = UserRepositoryImpl();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  UserRole _selectedRole = UserRole.teacher;
  bool _isLoading = false;
  bool _agreedToDataPrivacy = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name);
    _emailController = TextEditingController(text: widget.user?.email);
    _passwordController = TextEditingController(text: widget.user?.password);
    if (widget.user != null) {
      _selectedRole = widget.user!.role;
    }
  }

  void _saveUser() async {
    if (_formKey.currentState!.validate()) {
      if (!_agreedToDataPrivacy) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please accept the Data Privacy Notice (RA 10173 & RA 12199)'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final isEdit = widget.user != null;
      if (isEdit) {
        final confirmed = await ConfirmationDialog.showEdit(
          context: context,
          itemName: _nameController.text,
        );
        if (!confirmed) return;
      }

      setState(() => _isLoading = true);

      try {
        final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
        
        final user = UserModel(
          id: widget.user?.id,
          uid: widget.user?.uid ?? 'temp-${DateTime.now().millisecondsSinceEpoch}',
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole,
          status: widget.user?.status ?? 'active',
          createdAt: widget.user?.createdAt ?? now,
          updatedAt: now,
          isSynced: false,
        );

        if (widget.user == null) {
          await _repository.createUser(user);
        } else {
          await _repository.updateUser(user);
        }

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.user == null ? 'User created successfully' : 'User updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user == null ? 'Create Account' : 'Edit Account'),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.user == null ? 'Register New User' : 'Update User Details',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Assign proper roles and verify email addresses under RA 10173 compliance.'),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) => Validators.validateRequired(v, 'Full Name'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: widget.user == null,
                    validator: Validators.validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (v) => widget.user == null ? Validators.validatePassword(v, minLength: 6) : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserRole>(
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Account Role',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.admin_panel_settings),
                    ),
                    items: UserRole.values.map((r) => DropdownMenuItem(
                      value: r, 
                      child: Text(r.name.toUpperCase()),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedRole = val!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _agreedToDataPrivacy,
                        onChanged: (val) => setState(() => _agreedToDataPrivacy = val ?? false),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => TermsPrivacyDialog.show(context),
                          child: const Text(
                            'User Data Privacy & Compliance Notice (RA 10173 & RA 12199)',
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
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveUser,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(widget.user == null ? 'Create Account' : 'Update Account', style: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
