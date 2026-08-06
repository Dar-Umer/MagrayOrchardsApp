import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  String? _error;
  int _resendSeconds = 30;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

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

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    if (_otp.length != 4) {
      setState(() { _error = 'Please enter the complete 4-digit OTP'; });
      return;
    }
    setState(() { _error = null; });
    final auth = context.read<AuthProvider>();
    try {
      final success = await auth.verifyOtp(_otp);
      if (success && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() { _error = e is ApiException ? e.message : 'Invalid OTP. Please try again.'; });
    }
  }

  Future<void> _resendOtp() async {
    final auth = context.read<AuthProvider>();
    try {
      await auth.resendOtp();
      _startResendTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('OTP resent successfully'), backgroundColor: Theme.of(context).colorScheme.primary),
        );
      }
    } catch (e) {
      setState(() { _error = e is ApiException ? e.message : 'We couldn\'t resend the OTP. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final maskedPhone = auth.otpMaskedPhone ?? '****';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            auth.clearOtpState();
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.sms_outlined, size: 48, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 24),
                Text(
                  'Verify your phone',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 4-digit code sent to',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  '+91 $maskedPhone',
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 32),
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
                            if (_controllers[i].text.isEmpty && i > 0) {
                              _controllers[i - 1].clear();
                              _focusNodes[i - 1].requestFocus();
                            }
                          }
                        },
                        child: TextField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                          ),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (v) {
                            setState(() { _error = null; });
                            if (v.isNotEmpty && i < 3) {
                              _focusNodes[i + 1].requestFocus();
                            }
                            if (v.isNotEmpty && i == 3) {
                              FocusScope.of(context).unfocus();
                              _verifyOtp();
                            }
                          },
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
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
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _verifyOtp,
                    child: auth.isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Verify & Continue', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _resendSeconds > 0 ? null : _resendOtp,
                  child: Text(
                    _resendSeconds > 0
                        ? 'Resend OTP in ${_resendSeconds}s'
                        : 'Resend OTP',
                    style: TextStyle(color: _resendSeconds > 0 ? Colors.grey : theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _resendSeconds > 0 ? null : _resendOtp,
                  child: Text(
                    _resendSeconds > 0
                        ? 'Resend OTP in ${_resendSeconds}s'
                        : 'Resend OTP',
                    style: TextStyle(color: _resendSeconds > 0 ? Colors.grey : theme.colorScheme.primary),
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
