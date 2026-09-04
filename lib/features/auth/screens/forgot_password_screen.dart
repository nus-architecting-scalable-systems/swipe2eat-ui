import 'package:flutter/material.dart';

import '../../../core/widgets/gradient_button.dart';
import '../services/user_auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  bool _isResending = false;
  bool _codeSent = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validateCode(String? value) {
    if (!_codeSent) return null;
    if (value == null || value.isEmpty) {
      return 'Reset code is required';
    }
    if (value.length != 6 || !RegExp(r'^\d+$').hasMatch(value)) {
      return 'Code must be 6 digits';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (!_codeSent) return null;
    if (value == null || value.isEmpty) {
      return 'New password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (!_codeSent) return null;
    if (value == null || value.isEmpty) {
      return 'Please confirm your new password';
    }
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _handleSendCode() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await UserAuthService.forgotPassword(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() => _codeSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Password reset code sent to your email',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to send reset code';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleResetPassword() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await UserAuthService.confirmForgotPassword(
        email: _emailController.text.trim(),
        confirmationCode: _codeController.text.trim(),
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ??
                  'Password reset successful. You can now sign in.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/sign-in',
          (route) => false,
        );
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Password reset failed';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleResendCode() async {
    setState(() {
      _errorMessage = null;
      _isResending = true;
    });

    try {
      final result = await UserAuthService.forgotPassword(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['success'] == true
                ? (result['message'] ??
                      'Password reset code sent to your email')
                : (result['error'] ?? 'Failed to resend reset code'),
          ),
          backgroundColor: result['success'] == true
              ? Colors.green
              : Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to resend reset code'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Color(0xFF111827),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _codeSent ? 'Reset Your Password' : 'Forgot Password?',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _codeSent
                      ? 'Enter the reset code sent to your email and choose a new password.'
                      : 'Enter your email address and we will send you a password reset code.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF6B4A),
                        width: 2,
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  enabled: !_isLoading,
                  textInputAction: _codeSent
                      ? TextInputAction.next
                      : TextInputAction.done,
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'Reset Code',
                      hintText: '123456',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF6B4A),
                          width: 2,
                        ),
                      ),
                      prefixIcon: const Icon(
                        Icons.verified_outlined,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: _validateCode,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Enter your new password',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF6B4A),
                          width: 2,
                        ),
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Color(0xFF6B7280),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showNewPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _showNewPassword = !_showNewPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: !_showNewPassword,
                    validator: _validatePassword,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      hintText: 'Confirm your new password',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF6B4A),
                          width: 2,
                        ),
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Color(0xFF6B7280),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _showConfirmPassword = !_showConfirmPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: !_showConfirmPassword,
                    validator: _validateConfirmPassword,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: _isResending || _isLoading
                          ? null
                          : _handleResendCode,
                      child: Text(
                        _isResending ? 'Sending...' : 'Resend code',
                        style: const TextStyle(
                          color: Color(0xFFFF6B4A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _isLoading
                      ? Container(
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF8A3D), Color(0xFFFF4D4D)],
                            ),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 2.5,
                              ),
                            ),
                          ),
                        )
                      : GradientButton(
                          text: _codeSent
                              ? 'Reset Password'
                              : 'Send Reset Code',
                          onTap: _codeSent
                              ? _handleResetPassword
                              : _handleSendCode,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
