import 'dart:async';
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
  const PhoneInputScreen({super.key, this.initialRegister = false});

  final bool initialRegister;

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late bool _isRegister = widget.initialRegister;
  late bool _passwordLogin = !ShopConfig.otpVerificationEnabled;
  bool _obscurePassword = true;
  String? _error;

  Timer? _skipTimer;
  bool _showSkipButton = false;

  @override
  void initState() {
    super.initState();
    _skipTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showSkipButton = true);
      }
    });
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
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
    final scheme = theme.colorScheme;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App title only (No logo per user instruction)
                  Text(
                    'Magray Orchards',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isRegister
                        ? 'Create your account to get started'
                        : 'Sign in to access your orchard orders & services',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Polished Mode Selector Tab (Sign In / Create Account)
                  Container(
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (_isRegister) {
                                setState(() {
                                  _isRegister = false;
                                  _passwordLogin = !ShopConfig.otpVerificationEnabled;
                                  _error = null;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: !_isRegister ? scheme.surface : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !_isRegister
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'Sign In',
                                style: TextStyle(
                                  fontWeight: !_isRegister ? FontWeight.bold : FontWeight.w500,
                                  color: !_isRegister ? scheme.primary : Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (!_isRegister) {
                                setState(() {
                                  _isRegister = true;
                                  _error = null;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _isRegister ? scheme.surface : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _isRegister
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'Create Account',
                                style: TextStyle(
                                  fontWeight: _isRegister ? FontWeight.bold : FontWeight.w500,
                                  color: _isRegister ? scheme.primary : Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Main Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_isRegister) ...[
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                hintText: 'Enter your name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                hintText: 'example@gmail.com',
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

                          // Mobile Number Field
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              labelText: 'Mobile Number',
                              hintText: '10-digit number',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              prefixText: '+91 ',
                              prefixStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                              counterText: '',
                            ),
                            validator: _validatePhone,
                          ),

                          // Password Field (When Registering or Password Login selected)
                          if (_isRegister || _passwordLogin) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: _isRegister ? 'At least 8 characters' : 'Enter your password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: Colors.grey.shade600,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Please enter your password';
                                if (_isRegister && v.length < 8) return 'Password must be at least 8 characters';
                                return null;
                              },
                            ),
                          ],

                          // Forgot Password Link (Login mode only)
                          if (!_isRegister && _passwordLogin) ...[
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // OTP / Password toggle pill (for login if OTP is active)
                          if (!_isRegister && ShopConfig.otpVerificationEnabled) ...[
                            const SizedBox(height: 12),
                            Container(
                              height: 44,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() {
                                        _passwordLogin = false;
                                        _error = null;
                                      }),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: !_passwordLogin ? scheme.surface : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: !_passwordLogin
                                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)]
                                              : null,
                                        ),
                                        child: Text(
                                          'Login via OTP',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: !_passwordLogin ? FontWeight.bold : FontWeight.w500,
                                            color: !_passwordLogin ? scheme.primary : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() {
                                        _passwordLogin = true;
                                        _error = null;
                                      }),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _passwordLogin ? scheme.surface : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: _passwordLogin
                                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)]
                                              : null,
                                        ),
                                        child: Text(
                                          'Login via Password',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: _passwordLogin ? FontWeight.bold : FontWeight.w500,
                                            color: _passwordLogin ? scheme.primary : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Error Display Box
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFB91C1C),
                                        fontSize: 13,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Primary Action Button
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: scheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  : Text(
                                      _isRegister
                                          ? (ShopConfig.otpVerificationEnabled ? 'Send Verification OTP' : 'Create Account')
                                          : (_passwordLogin ? 'Sign In' : 'Send Login OTP'),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Bottom Toggle Prompt
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _isRegister = !_isRegister;
                        _passwordLogin = !_isRegister && !ShopConfig.otpVerificationEnabled;
                        _error = null;
                      }),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                          children: [
                            TextSpan(text: _isRegister ? 'Already have an account? ' : "Don't have an account? "),
                            TextSpan(
                              text: _isRegister ? 'Sign In' : 'Create One',
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Delayed Skip Button (Appears gracefully after 3-4 seconds)
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 350),
                    crossFadeState: _showSkipButton
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox(height: 12),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 8),
                      child: Center(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const HomeScreen()),
                            );
                          },
                          icon: Icon(Icons.arrow_forward_rounded, size: 16, color: scheme.primary),
                          label: Text(
                            'Skip for now & Explore App',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: scheme.primary.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            backgroundColor: scheme.primary.withValues(alpha: 0.04),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  // Kashmir footer
                  Text(
                    'Magray Orchards • Farm Care & Agriculture • Kashmir',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
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
