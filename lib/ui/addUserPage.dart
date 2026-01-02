import 'package:flutter/material.dart';
import 'package:flutter/system.dart';
import 'package:project_program/network/api_service.dart';
import 'package:project_program/entity/data/user.dart';
import 'package:project_program/entity/data/company.dart';
import 'package:project_program/entity/data/schedule.dart';
import 'package:project_program/entity/data_list.dart';
import 'package:provider/provider.dart';
import 'package:project_program/theme/theme_manager.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _innController = TextEditingController();
  final TextEditingController _fioController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  List<Company> _companies = [];
  List<Schedule> _schedules = [];
  Company? _selectedCompany;
  Schedule? _selectedSchedule;
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _innController.dispose();
    _fioController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final companies = await ApiService.getOrganizations(null, null, null, null);
    final schedules = await ApiService.geSchedules(null, null, null);

    try {

      setState(() {
        _companies = companies.data;
        _schedules = schedules.data;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }
  }

  List<String> _parseFIO(String fio) {
    final parts = fio.trim().split(' ');
    if (parts.length >= 3) {
      return [parts[0], parts[1], parts[2]];
    } else if (parts.length == 2) {
      return [parts[0], parts[1], ''];
    } else if (parts.length == 1) {
      return [parts[0], '', ''];
    }
    return ['', '', ''];
  }

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCompany == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите организацию')),
      );
      return;
    }

    if (_selectedSchedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите отдел')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final fioParts = _parseFIO(_fioController.text.trim());
      final user = User(
        id: int.parse(_innController.text.trim()),
        company_id: _selectedCompany!.id,
        depart_id: _selectedSchedule!.id,
        schedule_id: _selectedSchedule!.id,
        first_name: fioParts[1],
        last_name: fioParts[0],
        patronymic: fioParts[2],
        role: 'user',
        password: _passwordController.text,
      );

      final response = await ApiService.registration(user);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: response.code == 200 ? Colors.green : Colors.red,
          ),
        );
        
        if (response.code == 200) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  String? _validateINN(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Заполните это поле.';
    }
    final digits = value.trim();
    if (!RegExp(r'^\d+$').hasMatch(digits)) {
      return 'ИНН должен содержать только цифры.';
    }
    if (digits.length != 10 && digits.length != 12) {
      return 'ИНН должен содержать 10 или 12 цифр.';
    }
    return null;
  }

  String? _validateFIO(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Заполните это поле.';
    }
    final parts = value.trim().split(' ');
    if (parts.length < 2) {
      return 'Введите Фамилию Имя Отчество.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Заполните это поле.';
    }
    if (value.length < 6) {
      return 'Пароль должен содержать минимум 6 символов.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Заполните это поле.';
    }
    if (value != _passwordController.text) {
      return 'Пароли не совпадают.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Добавление пользователя',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Кнопка переключения темы
          Consumer<ThemeManager>(
            builder: (context, themeManager, child) {
              return IconButton(
                onPressed: () => themeManager.toggleTheme(),
                icon: Icon(
                  themeManager.isDarkMode 
                      ? Icons.light_mode 
                      : Icons.dark_mode,
                ),
                tooltip: themeManager.isDarkMode 
                    ? 'Светлая тема' 
                    : 'Темная тема',
              );
            },
          ),
        ],
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  constraints: const BoxConstraints(maxWidth: 500),
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Регистрация',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Заполните форму для создания учетной записи',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        // Поле ИНН
                        TextFormField(
                          controller: _innController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: _validateINN,
                          decoration: InputDecoration(
                            labelText: 'ИНН',
                            hintText: '10 или 12 цифр',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Поле ФИО
                        TextFormField(
                          controller: _fioController,
                          validator: _validateFIO,
                          decoration: InputDecoration(
                            labelText: 'ФИО',
                            hintText: 'Иванов Иван Иванович',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Выпадающий список ОГРН компании
                        DropdownButtonFormField<Company>(
                          value: _selectedCompany,
                          decoration: InputDecoration(
                            labelText: 'ОГРН компании',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: _companies.map((company) {
                            return DropdownMenuItem<Company>(
                              value: company,
                              child: Text('${company.name} (${company.id})'),
                            );
                          }).toList(),
                          onChanged: (Company? value) {
                            setState(() {
                              _selectedCompany = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Выберите организацию.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Выпадающий список ID отдела
                        DropdownButtonFormField<Schedule>(
                          value: _selectedSchedule,
                          decoration: InputDecoration(
                            labelText: 'ID отдела',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: _schedules.map((schedule) {
                            return DropdownMenuItem<Schedule>(
                              value: schedule,
                              child: Text('Отдел ${schedule.id.toString().padLeft(3, '0')}'),
                            );
                          }).toList(),
                          onChanged: (Schedule? value) {
                            setState(() {
                              _selectedSchedule = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Выберите отдел.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Поле пароля
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          validator: _validatePassword,
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            hintText: 'Минимум 6 символов',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Поле подтверждения пароля
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          validator: _validateConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Подтвердите пароль',
                            hintText: 'Повторите пароль',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Кнопка Добавить
                        ElevatedButton(
                          onPressed: _isLoading ? null : _addUser,
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
                                  'Добавить',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
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