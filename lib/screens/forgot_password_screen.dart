import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialPhone;
  final bool popOnSuccess;

  const ForgotPasswordScreen({
    super.key,
    this.initialPhone,
    this.popOnSuccess = false,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());
  final _formKey = GlobalKey<FormState>();
  bool _otpSent = false;
  String? _error;
  int _resendSeconds = 30;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPhone?.trim();
    if (initial != null && initial.isNotEmpty) {
      _phoneController.text = _cleanPhone(initial);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    super.dispose();
  }

  String _cleanPhone(String phone) {
    phone = phone.replaceAll(RegExp(r'[\s\-]'), '');
    if (phone.startsWith('+91')) phone = phone.substring(3);
    if (phone.startsWith('91') && phone.length > 10) phone = phone.substring(2);
    if (phone.startsWith('0')) phone = phone.substring(1);
    return phone;
  }

  String get _otp => _otpControllers.map((c) => c.text).join();

  void _startResendTimer() {
    _resendSeconds = 30;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_resendSeconds > 0) {
        _resendSeconds--;
        setState(() {});
        return true;
      }
      return false;
    });
  }

  Future<void> _sendOtp() async {
    final phone = _cleanPhone(_phoneController.text.trim());
    if (phone.length != 10 || !RegExp(r'^[6-9]').hasMatch(phone)) {
      setState(() { _error = 'Please enter a valid 10-digit mobile number'; });
      return;
    }
    final auth = context.read<AuthProvider>();
    setState(() { _error = null; });
    try {
      await auth.forgotPassword(phone);
      if (mounted) {
        setState(() { _otpSent = true; });
        _startResendTimer();
      }
    } catch (e) {
      setState(() { _error = e is ApiException ? e.message : 'Could not send OTP. Please try again.'; });
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_otp.length != 4) {
      setState(() { _error = 'Please enter the complete 4-digit OTP'; });
      return;
    }
    final auth = context.read<AuthProvider>();
    setState(() { _error = null; });
    try {
      final success = await auth.resetPassword(_otp, _newPasswordController.text);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password reset successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        if (widget.popOnSuccess) {
          Navigator.pop(context, true);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      setState(() { _error = e is ApiException ? e.message : 'Could not reset password. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.colorScheme.primary,
        title: const Text('Reset Password'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_reset, size: 48, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _otpSent ? 'Set a new password' : 'Forgot your password?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _otpSent
                        ? 'Enter the 4-digit code sent to your mobile and choose a new password.'
                        : 'Enter your mobile number and we\'ll send you an OTP to reset your password.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                    ),
                  if (!_otpSent) ...[
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        prefixText: '+91 ',
                        prefixStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                        counterText: '',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter your phone number';
                        final cleaned = _cleanPhone(v.trim());
                        if (cleaned.length != 10) return 'Phone must be 10 digits';
                        if (!RegExp(r'^[6-9]').hasMatch(cleaned)) return 'Must start with 6, 7, 8, or 9';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _sendOtp,
                        child: auth.isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Send OTP', style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        return Container(
                          width: 56,
                          height: 60,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          child: RawKeyboardListener(
                            focusNode: FocusNode(),
                            onKey: (event) {
                              if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                                if (_otpControllers[i].text.isEmpty && i > 0) {
                                  _otpControllers[i - 1].clear();
                                  _otpFocusNodes[i - 1].requestFocus();
                                }
                              }
                            },
                            child: TextField(
                              controller: _otpControllers[i],
                              focusNode: _otpFocusNodes[i],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(counterText: '', contentPadding: EdgeInsets.zero),
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (v) {
                                setState(() { _error = null; });
                                if (v.isNotEmpty && i < 3) {
                                  _otpFocusNodes[i + 1].requestFocus();
                                }
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Please enter a new password';
                        if (v.length < 8) return 'Password must be at least 8 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Please confirm your password';
                        if (v != _newPasswordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _resetPassword,
                        child: auth.isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Reset Password', style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _resendSeconds > 0 ? null : _sendOtp,
                      child: Text(
                        _resendSeconds > 0
                            ? 'Resend OTP in ${_resendSeconds}s'
                            : 'Resend OTP',
                        style: TextStyle(color: _resendSeconds > 0 ? Colors.grey : theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
