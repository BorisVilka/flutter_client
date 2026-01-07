import 'package:flutter/material.dart';
//import 'package:flutter/system.dart';
import 'package:flutter/services.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:project_program/network/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_program/ui/adminPage.dart';
import 'package:project_program/ui/employeePage.dart';
import 'package:project_program/ui/managerPage.dart';
import 'package:provider/provider.dart';
import 'package:project_program/theme/theme_manager.dart';

import '../network/constants.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _LoginState();
  }
}

class _LoginState extends State<LoginPage> {
  final TextEditingController _innController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showInnError = false;
  bool _showPasswordError = false;
  bool _showLoginError = false;
  bool _isLoading = false;
  String? _innErrorText;

  @override
  void dispose() {
    _innController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _validateAndLogin() async {
    final innText = _innController.text.trim();
    final passwordText = _passwordController.text.trim();
    
    setState(() {
      // Валидация ИНН
      if (innText.isEmpty) {
        _showInnError = true;
        _innErrorText = 'Заполните это поле.';
      } else if (!RegExp(r'^\d+$').hasMatch(innText)) {
        _showInnError = true;
        _innErrorText = 'ИНН должен содержать только цифры.';
      } else {
        _showInnError = false;
        _innErrorText = null;
      }
      
      // Валидация пароля
      _showPasswordError = passwordText.isEmpty;
      _showLoginError = false;
    });

    if (!_showInnError && !_showPasswordError) {
      setState(() {
        _isLoading = true;
        _showLoginError = false;
      });

      try {
        final loginBody = await ApiService.login(int.parse(innText), passwordText);
        
        // Сохраняем токен через shared_preferences
        Get.put(loginBody.token,tag: Constants.token_tag_storage);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(Constants.token_tag_storage, loginBody.token);
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _showLoginError = false;
          });
          
          // Переход на страницу в зависимости от роли
          if (loginBody.role == 'admin') {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const AdminPage()),
            );
          } else if (loginBody.role == 'moderator') {
            // Переход на страницу начальника отдела
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ManagerPage(
                  userId: loginBody.id,
                ),
              ),
            );
          } else if (loginBody.role == 'user') {
            // Переход на страницу сотрудника
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => EmployeePage(
                  userId: loginBody.id,
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _showLoginError = true;
          });
        }
      }
    }
  }
  
  bool _isInnValid(String value) {
    if (value.trim().isEmpty) return false;
    return RegExp(r'^\d+$').hasMatch(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Заголовок
                const Text(
                  'Вход в систему',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Подзаголовок
                const Text(
                  'Введите ваш ИНН и пароль для входа',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Поле ИНН
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showInnError) ...[
                      _buildErrorTooltip(_innErrorText ?? 'Заполните это поле.'),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: _innController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) {
                        if (_showInnError && _isInnValid(value)) {
                          setState(() {
                            _showInnError = false;
                            _innErrorText = null;
                          });
                        }
                        if (_showLoginError) {
                          setState(() {
                            _showLoginError = false;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'ИНН (логин)',
                        hintText: 'Введите ИНН',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Поле пароля
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showPasswordError) ...[
                      _buildErrorTooltip('Заполните это поле.'),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      onChanged: (value) {
                        if (_showPasswordError && value.trim().isNotEmpty) {
                          setState(() {
                            _showPasswordError = false;
                          });
                        }
                        if (_showLoginError) {
                          setState(() {
                            _showLoginError = false;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Пароль',
                        hintText: 'Введите пароль',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    if (_showLoginError) ...[
                      const SizedBox(height: 8),
                      _buildLoginError(),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                // Кнопка Войти
                ElevatedButton(
                  onPressed: _isLoading ? null : _validateAndLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Войти',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                // Кнопка переключения темы
                Consumer<ThemeManager>(
                  builder: (context, themeManager, child) {
                    return IconButton(
                      onPressed: () => themeManager.toggleTheme(),
                      icon: Icon(
                        themeManager.isDarkMode 
                            ? Icons.light_mode 
                            : Icons.dark_mode,
                        color: Colors.grey,
                      ),
                      tooltip: themeManager.isDarkMode 
                          ? 'Светлая тема' 
                          : 'Темная тема',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorTooltip(String message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.orange,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Неверный ИНН или пароль',
        style: TextStyle(
          color: Colors.red,
          fontSize: 13,
        ),
      ),
    );
  }
}