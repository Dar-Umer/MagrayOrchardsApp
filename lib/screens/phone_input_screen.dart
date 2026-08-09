import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/shop_config.dart';
import 'otp_verify_screen.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isRegister = false;
  late bool _passwordLogin = !ShopConfig.otpVerificationEnabled;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _cleanPhone(String phone) {
    phone = phone.replaceAll(RegExp(r'[\s\-]'), '');
    if (phone.startsWith('+91')) phone = phone.substring(3);
    if (phone.startsWith('91') && phone.length > 10) phone = phone.substring(2);
    if (phone.startsWith('0')) phone = phone.substring(1);
    return phone;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter your phone number';
    final cleaned = _cleanPhone(v.trim());
    if (cleaned.length != 10) return 'Phone must be 10 digits';
    if (!RegExp(r'^[6-9]').hasMatch(cleaned)) return 'Must start with 6, 7, 8, or 9';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    setState(() { _error = null; });
    final phone = _cleanPhone(_phoneController.text.trim());
    try {
      if (_isRegister) {
        if (ShopConfig.otpVerificationEnabled) {
          await auth.sendOtp(
            phone,
            type: 'register',
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const OtpVerifyScreen()),
            );
          }
        } else {
          final success = await auth.register(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: phone,
            password: _passwordController.text,
          );
          if (success && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        }
      } else if (_passwordLogin) {
        final success = await auth.loginWithPassword(phone, _passwordController.text);
        if (success && mounted) {
          if (ShopConfig.otpVerificationEnabled && !auth.isPhoneVerified) {
            _showVerifyPhonePrompt();
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        }
      } else {
        await auth.sendOtp(phone, type: 'login');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OtpVerifyScreen()),
          );
        }
      }
    } catch (e) {
      setState(() { _error = e is ApiException ? e.message : 'Could not complete the request. Please try again.'; });
    }
  }

  Future<void> _showVerifyPhonePrompt() async {
    final auth = context.read<AuthProvider>();
    final phone = _cleanPhone(_phoneController.text.trim());
    final verifyNow = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify your phone'),
        content: Text('Secure your account by verifying your mobile number +91 $phone. You can skip this for now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Skip for now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verify Now'),
          ),
        ],
      ),
    );

    if (verifyNow == true && mounted) {
      try {
        await auth.sendOtp(phone, type: 'login');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OtpVerifyScreen()),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } else if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
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
                      child: Icon(Icons.eco, size: 48, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Magray Orchards',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRegister ? 'Create your account' : 'Welcome back',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    if (_isRegister) ...[
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_isRegister) ...[
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Please enter your email';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
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
                      validator: _validatePhone,
                    ),
                    if (_isRegister || _passwordLogin) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter your password';
                          if (_isRegister && v.length < 8) return 'Password must be at least 8 characters';
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (!_isRegister)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                            );
                          },
                          child: const Text('Forgot password?'),
                        ),
                      ),
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
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _submit,
                        child: auth.isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Text(
                                _isRegister
                                    ? (ShopConfig.otpVerificationEnabled ? 'Send OTP' : 'Create Account')
                                    : (_passwordLogin ? 'Sign In' : 'Send OTP'),
                                style: const TextStyle(fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_isRegister && ShopConfig.otpVerificationEnabled) ...[
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('OTP')),
                          ButtonSegment(value: true, label: Text('Password')),
                        ],
                        selected: {_passwordLogin},
                        onSelectionChanged: (s) {
                          setState(() {
                            _passwordLogin = s.first;
                            _error = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_isRegister ? 'Already have an account?' : "Don't have an account?"),
                        TextButton(
                          onPressed: () => setState(() {
                            _isRegister = !_isRegister;
                            _passwordLogin = !_isRegister && !ShopConfig.otpVerificationEnabled;
                            _error = null;
                          }),
                          child: Text(_isRegister ? 'Sign In' : 'Create One'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
