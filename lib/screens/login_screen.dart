import 'package:flutter/material.dart';
import 'phone_input_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhoneInputScreen(initialRegister: false);
  }
}
