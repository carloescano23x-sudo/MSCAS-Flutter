import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/uls_logo.dart';

class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({super.key});

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();

  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      if (result['success'] != true) {
        setState(() {
          _errorMessage = result['message']?.toString() ?? 'Unable to sign in.';
          _isLoading = false;
        });

        return;
      }

      final role = result['role']?.toString().trim().toLowerCase();

      switch (role) {
        case 'instructor':
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/web-instructor-dashboard',
            (route) => false,
          );
          break;

        case 'admin':
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/web-admin-dashboard',
            (route) => false,
          );
          break;

        case 'student':
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/web-access-denied',
            (route) => false,
          );
          break;

        default:
          await _authService.logout();

          if (!mounted) {
            return;
          }

          setState(() {
            _errorMessage = 'This account does not have a valid MSCAS role.';
            _isLoading = false;
          });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unexpected login error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _microsoftLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _authService.signInWithMicrosoft();
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            result['message']?.toString() ??
            'Unable to start Microsoft sign-in.';
      });
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Enter your email address first.';
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.resetPassword(email);

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });

    final message =
        result['message']?.toString() ?? 'Unable to process request.';

    if (result['success'] == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } else {
      setState(() {
        _errorMessage = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Card(
              elevation: 6,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;

                  if (wide) {
                    return Row(
                      children: [
                        const Expanded(child: _WelcomePanel()),
                        Expanded(
                          child: _LoginPanel(
                            formKey: _formKey,
                            emailController: _emailController,
                            passwordController: _passwordController,
                            isLoading: _isLoading,
                            obscurePassword: _obscurePassword,
                            errorMessage: _errorMessage,
                            onPasswordVisibilityChanged: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            onLogin: _login,
                            onMicrosoftLogin: _microsoftLogin,
                            onForgotPassword: _forgotPassword,
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      const _WelcomePanel(compact: true),
                      _LoginPanel(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        isLoading: _isLoading,
                        obscurePassword: _obscurePassword,
                        errorMessage: _errorMessage,
                        onPasswordVisibilityChanged: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        onLogin: _login,
                        onMicrosoftLogin: _microsoftLogin,
                        onForgotPassword: _forgotPassword,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  final bool compact;

  const _WelcomePanel({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: compact ? 240 : 580),
      padding: const EdgeInsets.all(48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const UlsLogo(size: 82),
          const SizedBox(height: 24),
          const Text(
            'MSCAS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Mobile Smart Classroom Attendance System',
            style: TextStyle(
              color: Color(0xFFE3F2FD),
              fontSize: 19,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Faculty & Administration Portal',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Access classes, attendance records, reports, and management tools through the MSCAS web portal.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;

  final bool isLoading;
  final bool obscurePassword;
  final String? errorMessage;

  final VoidCallback onPasswordVisibilityChanged;
  final VoidCallback onLogin;
  final VoidCallback onMicrosoftLogin;
  final VoidCallback onForgotPassword;

  const _LoginPanel({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.obscurePassword,
    required this.errorMessage,
    required this.onPasswordVisibilityChanged,
    required this.onLogin,
    required this.onMicrosoftLogin,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 55),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome back',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Color(0xFF172B4D),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in using your MSCAS account.',
              style: TextStyle(fontSize: 15, color: Color(0xFF6B778C)),
            ),
            const SizedBox(height: 34),

            if (errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF9A9A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFC62828),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Color(0xFFC62828)),
                      ),
                    ),
                  ],
                ),
              ),

            TextFormField(
              controller: emailController,
              enabled: !isLoading,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'name@uls.edu.ph',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';

                if (email.isEmpty) {
                  return 'Enter your email address.';
                }

                if (!email.contains('@')) {
                  return 'Enter a valid email address.';
                }

                return null;
              },
              onFieldSubmitted: (_) {
                if (!isLoading) {
                  onLogin();
                }
              },
            ),

            const SizedBox(height: 18),

            TextFormField(
              controller: passwordController,
              enabled: !isLoading,
              obscureText: obscurePassword,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: onPasswordVisibilityChanged,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter your password.';
                }

                return null;
              },
              onFieldSubmitted: (_) {
                if (!isLoading) {
                  onLogin();
                }
              },
            ),

            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLoading ? null : onForgotPassword,
                child: const Text('Forgot password?'),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: isLoading ? null : onLogin,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(isLoading ? 'Signing in...' : 'Sign in'),
              ),
            ),

            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onMicrosoftLogin,
                icon: const Icon(Icons.window_rounded),
                label: const Text('Continue with Microsoft'),
              ),
            ),

            const SizedBox(height: 24),

            const Divider(),

            const SizedBox(height: 18),

            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: Color(0xFF6B778C),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'The MSCAS Web Portal is available to instructors and administrators. Students should use the MSCAS mobile application.',
                    style: TextStyle(color: Color(0xFF6B778C), height: 1.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
