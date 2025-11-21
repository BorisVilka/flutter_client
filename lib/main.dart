import 'package:flutter/material.dart';
import 'package:project_program/ui/loginPage.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    routes: {
      '/': (c) => const LoginPage()
    },
  ));
}


