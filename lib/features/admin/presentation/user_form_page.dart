import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/user_model.dart';
import '../domain/repositories/user_repository.dart';
import '../data/repositories/user_repository_impl.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../auth/presentation/terms_and_conditions_screen.dart';

class UserFormPage extends StatefulWidget {
  final UserModel? user;
  const UserFormPage({super.key, this.user});

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  final UserRepository _repository = UserRepositoryImpl();

  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  UserRole _selectedRole = UserRole.teacher;
  bool _isLoading = false;
  bool _agreedToTerms = true;

  @override
  void initState() {
    super.initState();
    final nameParts = (widget.user?.name ?? '').trim().split(RegExp(r'\s+'));
    final firstName = nameParts.isEmpty || nameParts.first.isEmpty
        ? ''
        : nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.last : '';
    final middleName = nameParts.length > 2
        ? nameParts.sublist(1, nameParts.length - 1).join(' ')
        : '';
    _firstNameController = TextEditingController(text: firstName);
    _middleNameController = TextEditingController(text: middleName);
    _lastNameController = TextEditingController(text: lastName);
    _emailController = TextEditingController(text: widget.user?.email);
    _passwordController = TextEditingController(text: widget.user?.password);
    if (widget.user != null) {
      _selectedRole = widget.user!.role;
    }
  }

  void _saveUser() async {
    if (_formKey.currentState!.validate()) {
      final standardizedName = _standardizeName(
        [
          _firstNameController.text,
          _middleNameController.text,
          _lastNameController.text,
        ].where((part) => part.trim().isNotEmpty).join(' '),
      );
      final normalizedEmail = _emailController.text.trim().toLowerCase();
      final emailAlreadyUsed = await _repository.emailExists(
        normalizedEmail,
        excludingUid: widget.user?.uid,
      );
      if (emailAlreadyUsed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'An account with this email address already exists.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (widget.user?.isProtectedAdmin == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'The system ADMIN account is protected and cannot be changed.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (standardizedName.isEmpty) return;

      if (!_agreedToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You must agree to the Terms and Conditions before creating an account.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final isEdit = widget.user != null;
      final confirmed = isEdit
          ? await ConfirmationDialog.showEdit(
              context: context,
              itemName: standardizedName,
            )
          : await ConfirmationDialog.show(
              context: context,
              title: 'Confirm Create Account',
              message:
                  'Create a new ${_selectedRole.name.toUpperCase()} account for $standardizedName?',
              confirmLabel: 'Create Account',
              confirmColor: Colors.green,
              icon: Icons.person_add,
            );
      if (!confirmed) {
        return;
      }

      setState(() => _isLoading = true);

      try {
        final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

        final user = UserModel(
          id: widget.user?.id,
          uid:
              widget.user?.uid ??
              'temp-${DateTime.now().millisecondsSinceEpoch}',
          name: standardizedName,
          email: normalizedEmail,
          password: _passwordController.text,
          role: _selectedRole,
          status: widget.user?.status ?? 'active',
          createdAt: widget.user?.createdAt ?? now,
          updatedAt: now,
          isSynced: false,
          termsAcceptedAt: widget.user?.termsAcceptedAt ?? now,
        );

        if (widget.user == null) {
          await _repository.createUser(user);
        } else {
          await _repository.updateUser(user);
        }

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.user == null
                    ? 'User created successfully'
                    : 'User updated successfully',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to ${widget.user == null ? "create" : "update"} account: $e',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _standardizeName(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part.length == 1
              ? part.toUpperCase()
              : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isCompact = screenSize.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 32,
        vertical: 24,
      ),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: screenSize.height - 48,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.user == null ? 'Create Account' : 'Edit Account',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    widget.user == null
                        ? 'Register New User'
                        : 'Update User Details',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Assign proper roles and verify email addresses under RA 10173 & RA 12199 compliance.',
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        Validators.validatePersonName(v, 'First Name'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _middleNameController,
                    decoration: const InputDecoration(
                      labelText: 'Middle Name (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? null
                        : Validators.validatePersonName(v, 'Middle Name'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        Validators.validatePersonName(v, 'Last Name'),
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
                      helperText:
                          'At least 8 characters: Aa, 1, and symbol (e.g. Password123@)',
                    ),
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    validator: (v) => widget.user == null
                        ? Validators.validatePassword(v)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserRole>(
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Account Role',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.admin_panel_settings),
                    ),
                    items: const [UserRole.teacher, UserRole.parent]
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedRole = val!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _agreedToTerms,
                        onChanged: (val) =>
                            setState(() => _agreedToTerms = val ?? false),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final accepted =
                                await TermsAndConditionsScreen.show(context);
                            if (accepted == true) {
                              setState(() => _agreedToTerms = true);
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'I agree to the Terms and Conditions (RA 10173 & RA 12199)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveUser,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.user == null
                                    ? 'Create Account'
                                    : 'Update Account',
                              ),
                      ),
                    ],
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
