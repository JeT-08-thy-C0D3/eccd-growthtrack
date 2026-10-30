import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/auth_repository_impl.dart';
import '../../../shared/models/user_model.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/terms_privacy_dialog.dart';
import '../../../shared/widgets/brand_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.showPasswordResetSuccess = false});

  final bool showPasswordResetSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _ForgotPasswordPage extends StatefulWidget {
  const _ForgotPasswordPage({
    required this.authRepo,
    required this.initialEmail,
  });

  final AuthRepositoryImpl authRepo;
  final String initialEmail;

  @override
  State<_ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<_ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  Timer? _resendTimer;
  bool _isSending = false;
  bool _linkSent = false;
  int _secondsRemaining = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsRemaining = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _secondsRemaining <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsRemaining = 0);
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  Future<void> _sendVerificationLink() async {
    if (!_linkSent && !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      await widget.authRepo.sendPasswordResetEmail(
        _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _linkSent = true);
      _startResendTimer();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            final card = Card(
              elevation: 0,
              color: Colors.white.withValues(alpha: .96),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
                side: BorderSide(
                  color: BrandColors.green.withValues(alpha: .14),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Back to login'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: BrandColors.green.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: BrandColors.green,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _linkSent ? 'Verify it\'s you' : 'Forgot password?',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: BrandColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _linkSent
                        ? _buildVerificationStep(theme)
                        : _buildEmailStep(),
                    if (!_linkSent) ...[
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSending ? null : _sendVerificationLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BrandColors.green,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: _isSending
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Send verification link'),
                      ),
                    ],
                  ],
                ),
              ),
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                if (isDesktop)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: .54,
                      heightFactor: 1,
                      child: _ClassroomPanel(),
                    ),
                  )
                else
                  const ColoredBox(color: Color(0xFFF4F9EF)),
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? constraints.maxWidth * .58 : 20,
                    24,
                    24,
                    24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: card,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your registered Gmail account. We will send a secure link to verify it\'s you.',
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_isSending,
            onFieldSubmitted: (_) => _sendVerificationLink(),
            validator: Validators.validateEmail,
            decoration: const InputDecoration(
              labelText: 'Gmail address',
              hintText: 'name@gmail.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          if (_errorMessage != null) _buildErrorMessage(),
        ],
      ),
    );
  }

  Widget _buildVerificationStep(ThemeData theme) {
    final canResend = !_isSending && _secondsRemaining == 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: BrandColors.green.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            color: BrandColors.green,
            size: 30,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'We sent a verification link to ${_emailController.text.trim()}. Open the email and tap “Verify it\'s me” to set your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: canResend ? _sendVerificationLink : null,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(
            _secondsRemaining > 0
                ? 'Resend available in ${_secondsRemaining}s'
                : 'Resend verification link',
          ),
        ),
        if (_errorMessage != null) _buildErrorMessage(),
      ],
    );
  }

  Widget _buildErrorMessage() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700)),
  );
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepo = AuthRepositoryImpl();
  bool _isLoading = false;
  bool _agreedToTerms = false;
  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  late final AnimationController _logoController;

  static const _rememberMeKey = 'remember_login';
  static const _rememberedEmailKey = 'remembered_email';
  static const _passwordResetEmailKey = 'password_reset_email';

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _loadRememberedLogin();
    if (widget.showPasswordResetSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password updated successfully. You can now sign in using your new password.',
            ),
            backgroundColor: BrandColors.green,
          ),
        );
      });
    }
  }

  Future<void> _loadRememberedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_rememberMeKey) ?? false;
    final email = prefs.getString(_rememberedEmailKey) ?? '';
    final resetEmail = prefs.getString(_passwordResetEmailKey) ?? '';
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      // A Gmail reset verifies this email address. Prefill it on Login after
      // the password update, without ever storing the password locally.
      _emailController.text = remember ? email : resetEmail;
    });
  }

  Future<void> _saveRememberedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool(_rememberMeKey, true);
      await prefs.setString(_rememberedEmailKey, _emailController.text.trim());
    } else {
      await prefs.remove(_rememberMeKey);
      await prefs.remove(_rememberedEmailKey);
    }
  }

  Future<void> _forgotPassword() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ForgotPasswordPage(
          authRepo: _authRepo,
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );
  }

  Future<void> _reviewTermsAndAccept() async {
    final accepted = await TermsPrivacyDialog.show(context);
    if (mounted && accepted) {
      setState(() => _agreedToTerms = true);
    }
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please accept the Terms of Service & Privacy Notice (RA 10173 & RA 12199) to proceed.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _authRepo.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      setState(() => _isLoading = false);

      if (user != null && mounted) {
        await _saveRememberedLogin();
        if (!mounted) return;
        await _showLoginSuccessModal();
        if (!mounted) return;
        _navigateToDashboard(user.role);
      }
    } catch (error) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _showLoginSuccessModal() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                'Login successful!\nPreparing your dashboard...',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (mounted && navigator.canPop()) navigator.pop();
  }

  void _navigateToDashboard(UserRole role) {
    String route = '/';
    switch (role) {
      case UserRole.admin:
        route = '/admin';
        break;
      case UserRole.teacher:
        route = '/teacher';
        break;
      case UserRole.parent:
        route = '/parent';
        break;
    }
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final form = Form(
              key: _formKey,
              // Validate each login field only after that field is edited.
              // This prevents an untouched password from showing an error
              // while the user is still entering their email address.
              autovalidateMode: AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  Center(
                    child: AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, child) {
                        final entrance = Curves.easeOutBack
                            .transform(_logoController.value.clamp(0.0, 1.0))
                            .clamp(0.0, 1.0);
                        final float = Curves.easeInOut.transform(
                          _logoController.value,
                        );
                        return Opacity(
                          opacity: entrance,
                          child: Transform.translate(
                            offset: Offset(0, -5 * float),
                            child: Transform.scale(
                              scale: .78 + (.22 * entrance),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x180A5275),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: EccdLogo(height: 125, width: 150),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: BrandColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to continue supporting every child’s growth.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _emailController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    validator: Validators.validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_isLoading) _login();
                    },
                    validator: (v) => Validators.validatePassword(
                      v,
                      minLength: 6,
                      requireStrong: false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, _) {
                      return Row(
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: Checkbox(
                              value: _rememberMe,
                              visualDensity: VisualDensity.compact,
                              onChanged: (value) =>
                                  setState(() => _rememberMe = value ?? false),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Expanded(
                            child: Text(
                              'Remember me',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : _forgotPassword,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 64,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: BrandColors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Login  →',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreedToTerms,
                        onChanged: (checked) {
                          if (checked ?? false) {
                            _reviewTermsAndAccept();
                          } else {
                            setState(() => _agreedToTerms = false);
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          onTap: _reviewTermsAndAccept,
                          child: const Text(
                            'I accept the Terms & Privacy Notice (RA 10173 & RA 12199)',
                            textAlign: TextAlign.left,
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
                ],
              ),
            );

            final isDesktop = constraints.maxWidth >= 900;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (isDesktop)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: .54,
                      heightFactor: 1,
                      child: _ClassroomPanel(),
                    ),
                  )
                else
                  const ColoredBox(color: Color(0xFFF4F9EF)),
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? constraints.maxWidth * .56 : 20,
                    24,
                    24,
                    24,
                  ),
                  child: Center(
                    child: Card(
                      elevation: 0,
                      color: Colors.white.withValues(alpha: .96),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(36),
                        side: BorderSide(
                          color: BrandColors.green.withValues(alpha: .14),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isDesktop ? 38 : 24,
                          32,
                          isDesktop ? 38 : 24,
                          38,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: form,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ClassroomPanel extends StatelessWidget {
  const _ClassroomPanel();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/login_classroom.png',
          fit: BoxFit.cover,
          alignment: Alignment.centerLeft,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                BrandColors.navy.withValues(alpha: .16),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
}
