

import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<StatefulWidget> createState() {
   return _LoginState();
  }

}

class _LoginState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber[200]
          ),
          child: Column(
            children: [
              const TextField(),
              const TextField(),
              ElevatedButton(onPressed: () {}, child: const Text("LOGIN"))
            ],
          ),
        ),
      ),
    );
  }

}