import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/validators.dart';
import '../../../shared/widgets/brand_widgets.dart';

/// The recovery UI accepts either Firebase's legacy reset code or an Email
/// Link sign-in. The latter lets Spark-plan projects show their own UI.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    this.actionCode,
    this.emailLink,
    this.initialEmail = '',
  }) : assert(actionCode != null || emailLink != null);

  final String? actionCode;
  final String? emailLink;
  final String initialEmail;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isVerifying = false;
  bool _isUpdating = false;
  bool _verified = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _email;
  String? _errorMessage;

  bool get _usesEmailLink => widget.emailLink != null;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyItsMe() async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      late final String email;
      if (_usesEmailLink) {
        if (!auth.isSignInWithEmailLink(widget.emailLink!)) {
          throw FirebaseAuthException(code: 'invalid-action-code');
        }
        final preferences = await SharedPreferences.getInstance();
        email = widget.initialEmail.trim().isNotEmpty
            ? widget.initialEmail.trim().toLowerCase()
            : (preferences.getString('password_reset_email') ?? '')
                  .trim()
                  .toLowerCase();
        if (email.isEmpty) {
          throw FirebaseAuthException(code: 'missing-email');
        }
        final credential = await auth.signInWithEmailLink(
          email: email,
          emailLink: widget.emailLink!,
        );
        if (credential.user?.email?.toLowerCase() != email) {
          await auth.signOut();
          throw FirebaseAuthException(code: 'invalid-credential');
        }
      } else {
        email = await auth.verifyPasswordResetCode(widget.actionCode!);
      }
      if (!mounted) return;
      setState(() {
        _email = email;
        _verified = true;
      });
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.code == 'missing-email'
              ? 'Open this link on the same browser where you requested it, or request a new link.'
              : 'This verification link is invalid or has expired. Request a new password reset link.';
        });
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _updatePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isUpdating = true;
      _errorMessage = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_usesEmailLink) {
        // Never treat a missing temporary email-link session as a successful
        // password update. Firebase must confirm the update before Login is
        // shown, otherwise the old password would still be active.
        final user = auth.currentUser;
        if (user == null) {
          throw FirebaseAuthException(code: 'requires-recent-login');
        }
        await user.updatePassword(_passwordController.text);
      } else {
        await auth.confirmPasswordReset(
          code: widget.actionCode!,
          newPassword: _passwordController.text,
        );
      }
      // A reset link can sign the user in temporarily. End that session and
      // return directly to Login so the new password can be used immediately.
      await auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } on FirebaseAuthException {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to update the password. The verification link may have expired. Please request a new one.';
        });
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _verified
                        ? _buildPasswordForm(theme)
                        : _buildVerifyCard(theme),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyCard(ThemeData theme) => Column(
    key: const ValueKey('verify'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Center(child: EccdLogo(height: 86)),
      const SizedBox(height: 18),
      const Icon(
        Icons.verified_user_rounded,
        color: BrandColors.green,
        size: 50,
      ),
      const SizedBox(height: 16),
      Text(
        'Verify it\'s you',
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall?.copyWith(
          color: BrandColors.navy,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Confirm this secure email link before creating a new password.',
        textAlign: TextAlign.center,
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      ),
      if (_errorMessage != null) _buildError(),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: _isVerifying ? null : _verifyItsMe,
        icon: _isVerifying
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.verified_rounded),
        label: Text(_isVerifying ? 'Verifying...' : 'Verify it\'s me'),
      ),
      TextButton(
        onPressed: () =>
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/login', (_) => false),
        child: const Text('Back to login'),
      ),
    ],
  );

  Widget _buildPasswordForm(ThemeData theme) => Form(
    key: _formKey,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    child: Column(
      key: const ValueKey('password'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: EccdLogo(height: 78)),
        const SizedBox(height: 16),
        Text(
          'Create new password',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: BrandColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Verified for $_email',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          enabled: !_isUpdating,
          textInputAction: TextInputAction.next,
          validator: Validators.validatePassword,
          decoration: InputDecoration(
            labelText: 'New password',
            hintText: 'Password123@',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          enabled: !_isUpdating,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _updatePassword(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
          decoration: InputDecoration(
            labelText: 'Confirm new password',
            prefixIcon: const Icon(Icons.lock_reset_rounded),
            suffixIcon: IconButton(
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        if (_errorMessage != null) _buildError(),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updatePassword,
          child: _isUpdating
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Update password'),
        ),
      ],
    ),
  );

  Widget _buildError() => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Text(
      _errorMessage!,
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.red.shade700),
    ),
  );
}
