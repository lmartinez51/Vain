/// @file login_page.dart
/// @brief UI layout and orchestration for user authentication (Sign In/Sign Up).
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:vain_app/features/auth/controllers/login_controller.dart';
import 'package:vain_app/features/auth/models/auth_result.dart';
import 'package:vain_app/theme/magic_theme.dart';
import 'package:vain_app/features/auth/widgets/magic_textfield.dart';

/// @brief A StatefulWidget providing the tabbed interface for login and registration.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

/// @brief State class managing form validation, controller lifecycle, and login UI updates.
class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Keys para validar los formularios independientemente
  final _signInFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _isSignUpPasswordVisible = false;

  // Controllers
  final _emailSignInCtrl = TextEditingController();
  final _passwordSignInCtrl = TextEditingController();
  final _nameSignUpCtrl = TextEditingController();
  final _emailSignUpCtrl = TextEditingController();
  final _passwordSignUpCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Escuchar cambios para ocultar teclado si se cambia de tab
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailSignInCtrl.dispose();
    _passwordSignInCtrl.dispose();
    _nameSignUpCtrl.dispose();
    _emailSignUpCtrl.dispose();
    _passwordSignUpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MagicTheme.backgroundBlack,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                const _HeaderSection(),
                const SizedBox(height: 8),
                _buildTabBar(),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, child) {
                    return _tabController.index == 0
                        ? _buildSignInForm()
                        : _buildSignUpForm();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: TabBar(
        controller: _tabController,
        labelColor: MagicTheme.goldMain,
        labelStyle: MagicTheme.labelStyle.copyWith(fontSize: 18),
        unselectedLabelStyle:
            MagicTheme.labelStyle.copyWith(fontWeight: FontWeight.normal),
        unselectedLabelColor: MagicTheme.goldDark.withValues(alpha: 0.5),
        indicatorColor: MagicTheme.neonPurple,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        onTap: (index) {
          setState(() {}); // Forzar rebuild para cambiar el formulario visible
        },
        tabs: const [
          Tab(text: 'Sign In'),
          Tab(text: 'Sign Up'),
        ],
      ),
    );
  }

  // ----------------------
  // SIGN IN FORM
  // ----------------------

  /// @brief Generates the form layout specifically for returning users.
  /// @return A completed [Form] widget for sign-in.
  Widget _buildSignInForm() {
    // Usamos Consumer aquí para no reconstruir toda la página
    return Consumer<LoginController>(
      builder: (context, controller, child) {
        return Form(
          key: _signInFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MagicTextField(
                  labelText: 'Email',
                  hintText: 'Enter your email...',
                  controller: _emailSignInCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) => (value == null || !value.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                  onChanged: (value) {
                    _signUpFormKey.currentState?.validate();
                  },
                ),
                const SizedBox(height: 16),
                MagicTextField(
                  labelText: 'Password',
                  hintText: 'Enter your password...',
                  controller: _passwordSignInCtrl,
                  obscureText: !_isPasswordVisible,
                  autofillHints: const [AutofillHints.password],
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Password is required'
                      : null,
                  onChanged: (value) {
                    _signUpFormKey.currentState?.validate();
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: MagicTheme.goldMain,
                    ),
                    onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
                const SizedBox(height: 24),
                _MagicButton(
                  text: 'Log In',
                  isLoading: controller.isSubmitting,
                  onPressed: () => _handleSignIn(controller),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () async {
                    final email = _emailSignInCtrl.text.trim();

                    if (email.isEmpty) {
                      _showError(
                          "Please enter your email to reset your password.");
                      return;
                    }

                    final result = await controller.resetPassword(email);

                    if (!mounted) return;

                    if (result.success) {
                      _showMessage(
                          "Password reset email sent to $email.\nCheck your inbox.");
                    } else {
                      _showError(
                          result.message ?? "Could not send reset email.");
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: MagicTheme.goldMain.withValues(alpha: 0.5)),
                    backgroundColor: Colors.transparent,
                    foregroundColor: MagicTheme.goldLight,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    'Forgot Password?',
                    style: MagicTheme.labelStyle
                        .copyWith(fontSize: 14, shadows: null),
                  ),
                ),
                const SizedBox(height: 24),
                _SocialLoginRow(
                  isSignUp: false,
                  onGoogle: () => _handleGoogle(controller),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ----------------------
  // SIGN UP FORM
  // ----------------------

  /// @brief Generates the form layout specifically for new user registration.
  /// @return A completed [Form] widget for sign-up.
  Widget _buildSignUpForm() {
    return Consumer<LoginController>(
      builder: (context, controller, child) {
        return Form(
          key: _signUpFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MagicTextField(
                  labelText: 'Full Name',
                  controller: _nameSignUpCtrl,
                  hintText: 'Enter your full name...',
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Name is required'
                      : null,
                  onChanged: (value) {
                    _signUpFormKey.currentState?.validate();
                  },
                ),
                const SizedBox(height: 16),
                MagicTextField(
                  labelText: 'Email',
                  hintText: 'Enter your email...',
                  controller: _emailSignUpCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.newUsername],
                  validator: (value) => (value == null || !value.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                  onChanged: (value) {
                    _signUpFormKey.currentState?.validate();
                  },
                ),
                const SizedBox(height: 16),
                MagicTextField(
                  labelText: 'Password',
                  hintText: 'Enter your password...',
                  controller: _passwordSignUpCtrl,
                  obscureText: !_isSignUpPasswordVisible,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) => (value == null || value.length < 6)
                      ? 'Password must be at least 6 chars'
                      : null,
                  onChanged: (value) {
                    _signUpFormKey.currentState?.validate();
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isSignUpPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: MagicTheme.goldMain,
                    ),
                    onPressed: () => setState(() =>
                        _isSignUpPasswordVisible = !_isSignUpPasswordVisible),
                  ),
                ),
                const SizedBox(height: 16),
                _MagicButton(
                  text: 'Create Account',
                  isLoading: controller.isSubmitting,
                  onPressed: () => _handleSignUp(controller),
                ),
                const SizedBox(height: 24),
                _SocialLoginRow(
                  isSignUp: true,
                  onGoogle: () => _handleGoogle(controller),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ----------------------
  // LOGIC HANDLERS
  // ----------------------

  /// @brief Validates and executes the sign-in sequence using the active [LoginController].
  /// @param controller The injected authentication controller handling logic.
  /// @return A completed [Future] post-execution.
  Future<void> _handleSignIn(LoginController controller) async {
    // 1. Validar formulario primero
    if (!_signInFormKey.currentState!.validate()) return;

    // 2. Cerrar teclado para mejor UX
    FocusScope.of(context).unfocus();

    final result = await controller.signInWithEmail(
      _emailSignInCtrl.text.trim(),
      _passwordSignInCtrl.text.trim(),
    );
    _processAuthResult(result, controller);
  }

  /// @brief Validates and executes the sign-up sequence using the active [LoginController].
  /// @param controller The injected authentication controller handling logic.
  /// @return A completed [Future] post-execution.
  Future<void> _handleSignUp(LoginController controller) async {
    if (!_signUpFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final result = await controller.createAccount(
      _emailSignUpCtrl.text.trim(),
      _passwordSignUpCtrl.text.trim(),
    );
    _processAuthResult(result, controller);
  }

  /// @brief Initiates the Google OAuth login flow.
  /// @param controller The injected authentication controller handling logic.
  /// @return A completed [Future] post-execution.
  Future<void> _handleGoogle(LoginController controller) async {
    if (controller.isSubmitting) return;
    final result = await controller.signInWithGoogle();
    _processAuthResult(result, controller);
  }

  /// @brief Evaluates an [AuthResult] and triggers the corresponding navigation or error UI.
  /// @param result The outcome of the authentication attempt.
  /// @param controller The injected authentication controller.
  void _processAuthResult(AuthResult result, LoginController controller) async {
    if (!mounted) return;

    if (result.success) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } else {
      _showError(
          result.message ?? controller.errorMessage ?? 'Authentication failed');
    }
  }

  void _showSnack({
    required String message,
    required bool isError,
  }) {
    final theme = Theme.of(context);

    // Colores dinámicos Material 3
    final Color bgColor = isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primaryContainer;

    final Color textColor = isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;

    final IconData icon = isError ? Icons.error_outline : Icons.check_circle;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 6,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: bgColor,
        content: Row(
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    _showSnack(message: message, isError: true);
  }

  void _showMessage(String message) {
    _showSnack(message: message, isError: false);
  }
}

// -----------------------------------------------------------
// WIDGETS AUXILIARES (Header, Inputs, Social)
// -----------------------------------------------------------

/// @brief UI widget containing the application logo and magical background gradient for the login screen.
class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    // Reducido ligeramente la altura para pantallas pequeñas
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                MagicTheme.mysticPurple.withValues(alpha: 0.4),
                Colors.transparent,
              ],
              center: Alignment.center,
              radius: 0.8,
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/vain_logo.png',
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text(
                      'VAIN',
                      style: MagicTheme.titleStyle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Powered by Gemini',
                    style: MagicTheme.labelStyle.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// @brief UI widget rendering OAuth provider buttons horizontally.
class _SocialLoginRow extends StatelessWidget {
  final bool isSignUp;
  final VoidCallback onGoogle;

  const _SocialLoginRow({
    required this.isSignUp,
    required this.onGoogle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          isSignUp
              ? 'Sign up using social account'
              : 'Sign in using social account',
          style: const TextStyle(
            fontFamily: 'Readex Pro',
            color: MagicTheme.silver,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialButton(
              icon: FontAwesomeIcons.google,
              onPressed: onGoogle,
              color: MagicTheme.googleBlue(context),
            ),
            const SizedBox(width: 24),
            _SocialButton(
              icon: FontAwesomeIcons.apple,
              onPressed: () {},
              color: MagicTheme.appleGray(context),
            ),
          ],
        ),
      ],
    );
  }
}

/// @brief A circular button tailored for displaying a social platform icon.
class _SocialButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  const _SocialButton(
      {required this.icon,
      required this.onPressed,
      this.color = const Color.fromARGB(255, 255, 255, 255)});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      splashColor: MagicTheme.neonPurple.withValues(alpha: 0.3),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border:
              Border.all(color: MagicTheme.goldLight.withValues(alpha: 0.7)),
        ),
        alignment: Alignment.center,
        child: FaIcon(icon, color: color, size: 16),
      ),
    );
  }
}

/// @brief A prominent standard button boasting magical visual effects and a loading state.
class _MagicButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _MagicButton({
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          // Borde exterior: Simula un marco dorado
          border: Border.all(
            color: MagicTheme.goldMain,
            width: 1.5,
          ),
          // Relleno: Gradiente que simula un núcleo de energía
          gradient: LinearGradient(
            colors: [
              MagicTheme.mysticPurple.withValues(alpha: 0.8),
              MagicTheme.neonPurple.withValues(alpha: 0.9),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          // Sombra: Da el resplandor místico
          boxShadow: [
            BoxShadow(
              color: MagicTheme.neonPurple.withValues(alpha: 0.5),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  text,
                  style: MagicTheme.labelStyle.copyWith(
                    color: MagicTheme.goldMain,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 2,
                    shadows: null, // Quitamos el shadow para que sea más limpio
                  ),
                ),
        ),
      ),
    );
  }
}
