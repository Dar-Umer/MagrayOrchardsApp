import 'package:flutter/material.dart';
import 'phone_input_screen.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhoneInputScreen(initialRegister: true);
  }
}
