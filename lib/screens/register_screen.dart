import 'package:flutter/material.dart';
import 'phone_input_screen.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PhoneInputScreen()));
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
