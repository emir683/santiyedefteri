import 'package:flutter/material.dart';
import 'login_ekrani.dart';
import 'register_ekrani.dart';

class LoginOrRegister extends StatefulWidget {
  const LoginOrRegister({super.key});

  @override
  State<LoginOrRegister> createState() => _LoginOrRegisterState();
}

class _LoginOrRegisterState extends State<LoginOrRegister> {
  bool showLoginPage = true;

  void togglePages() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showLoginPage) {
      return LoginEkrani(onRegisterTap: togglePages);
    } else {
      return RegisterEkrani(onLoginTap: togglePages);
    }
  }
}
