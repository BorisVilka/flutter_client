import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_program/network/api_service.dart';
import 'package:project_program/entity/data/user.dart';
import 'package:project_program/entity/data/journal_item.dart';
import 'package:project_program/entity/data_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_program/network/constants.dart';
import 'package:provider/provider.dart';
import 'package:project_program/theme/theme_manager.dart';

class EmployeePage extends StatefulWidget {
  final int userId;

  const EmployeePage({
    super.key,
    required this.userId,
  });

  @override
  State<EmployeePage> createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  User? _user;
  JournalItem? _todayJournal;
  bool _isLoading = true;
  String _currentStatus = 'Не начато';
  TimeOfDay? _workStart;
  TimeOfDay? _workEnd;
  TimeOfDay? _breakStart;
  TimeOfDay? _breakEnd;
  DateTime? _workDate;
  
  String get _userName {
    if (_user != null) {
      return '${_user!.last_name} ${_user!.first_name} ${_user!.patronymic}';
    }
    return 'Пользователь';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Загружаем информацию о пользователе
      final usersList = await ApiService.getUsers(widget.userId, null, null, null, null, null, null, null, null, null);
      if (usersList.data.isNotEmpty) {
        _user = usersList.data.first;
      }

      // Загружаем записи журнала за сегодня
      final today = DateTime.now();
      final journalList = await ApiService.getJournalItemsByUser(
        widget.userId,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        today,
        null,
        null,
        null,
      );

      if (journalList.data.isNotEmpty) {
        _todayJournal = journalList.data.first;
        // Загружаем данные только если локальные значения не установлены (работа не начата в этой сессии)
        if (_workStart == null) {
          _workStart = _todayJournal!.start;
          _workEnd = _todayJournal!.end;
          _breakStart = _todayJournal!.pause;
          _breakEnd = _todayJournal!.pause;
          _workDate = _todayJournal!.date;

          // Определяем текущий статус
          if (_todayJournal!.status == 'working') {
            _currentStatus = 'В работе';
          } else if (_todayJournal!.status == 'break') {
            _currentStatus = 'На перерыве';
          } else if (_todayJournal!.status == 'finished') {
            _currentStatus = 'Завершено';
          } else {
            _currentStatus = 'Не начато';
          }
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }
  }

  Future<void> _startWork() async {
    // 1) При нажатии на кнопку начать - сохраняй текущее время
    setState(() {
      _workStart = TimeOfDay.now();
      _workDate = DateTime.now();
      _workEnd = null;
      _breakStart = null;
      _breakEnd = null;
      _currentStatus = 'В работе';
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Работа начата'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
  TimeOfDay pauseTimeOfDay(TimeOfDay? breakStart, TimeOfDay? breakEnd) {
    final start = _toMinutes(breakStart ?? const TimeOfDay(hour: 0, minute: 0));
    final end   = _toMinutes(breakEnd   ?? const TimeOfDay(hour: 0, minute: 0));

    final diff = end - start;
    if (diff <= 0) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
    final h = diff ~/ 60;
    final m = diff % 60;
    return TimeOfDay(hour: h, minute: m);
  }


  Future<void> _endWork() async {
    // 4) При нажатии на кнопку закончить работу - создавай объект JournalItem и отправляй запрос addJournalItem
    if (_workStart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала начните работу')),
      );
      return;
    }

    try {
      setState(() {
        _workEnd = TimeOfDay.now();
        _currentStatus = 'Завершено';
      });

      var random = Random();
      final journalItem = JournalItem(
        id: random.nextInt(2000000000),
        start: _workStart!,
        pause: pauseTimeOfDay(_breakStart, _breakEnd) ,
        end: _workEnd!,
        status: 'worked',
        note: '',
        user_inn: widget.userId,
        company_id: _user?.company_id ?? 0,
        schedule_id: _user?.depart_id ?? 0,
        date: _workDate ?? DateTime.now(),
      );

      final response = await ApiService.addJournalItem(journalItem);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: response.code == 200 ? Colors.green : Colors.red,
          ),
        );
        
        if (response.code == 200) {
          // Сбрасываем локальные данные после успешной отправки
          setState(() {
            _workStart = null;
            _workEnd = null;
            _breakStart = null;
            _breakEnd = null;
            _workDate = null;
            _currentStatus = 'Не начато';
          });
          await _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _startBreak() async {
    // 2) При нажатии на кнопку начать перерыв - сохраняй время начала перерыва
    if (_workStart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала начните работу')),
      );
      return;
    }

    setState(() {
      _breakStart = TimeOfDay.now();
      _breakEnd = null;
      _currentStatus = 'На перерыве';
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Перерыв начат'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _endBreak() async {
    // 3) При нажатии на кнопку закончить перерыв - сохраняй время конца перерыва
    if (_breakStart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала начните перерыв')),
      );
      return;
    }

    setState(() {
      _breakEnd = TimeOfDay.now();
      _currentStatus = 'В работе';
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Перерыв закончен'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Constants.token_tag_storage);
    Get.put("",tag: Constants.token_tag_storage);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null || (time.hour == 0 && time.minute == 0)) {
      return '—';
    }
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final weekdays = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];
    final months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    return '$weekday, ${now.day} $month ${now.year} г.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок
                  _buildHeader(),
                  const SizedBox(height: 16),
                  // Текущий статус
                  _buildCurrentStatusCard(),
                  const SizedBox(height: 16),
                  // Управление рабочим временем
                  _buildWorkTimeManagementCard(),
                  const SizedBox(height: 16),
                  // Записи времени
                  _buildTimeRecordsCard(),
                  const SizedBox(height: 16),
                  // Информация о пользователе
                  _buildUserInfoCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Панель сотрудника',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _userName,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        Row(
          children: [
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
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Обновить',
            ),
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Выйти'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Текущий статус',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getCurrentDate(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentStatus,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkTimeManagementCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Управление рабочим временем',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
              children: [
                ElevatedButton.icon(
                  onPressed: _workStart == null ? _startWork : null,
                  icon: const Icon(Icons.access_time),
                  label: const Text('Начать работу'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _workStart != null && _workEnd == null ? _endWork : null,
                  icon: const Icon(Icons.access_time),
                  label: const Text('Закончить работу'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink[200],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _workStart != null && _breakStart == null && _workEnd == null ? _startBreak : null,
                  icon: const Icon(Icons.coffee),
                  label: const Text('Начать перерыв'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _breakStart != null && _breakEnd == null && _workEnd == null ? _endBreak : null,
                  icon: const Icon(Icons.access_time),
                  label: const Text('Закончить перерыв'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRecordsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Записи времени',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTimeRecordRow('Начало работы:', _formatTime(_workStart)),
            const SizedBox(height: 12),
            _buildTimeRecordRow('Конец работы:', _formatTime(_workEnd)),
            const SizedBox(height: 12),
            _buildTimeRecordRow('Начало перерыва:', _formatTime(_breakStart)),
            const SizedBox(height: 12),
            _buildTimeRecordRow('Конец перерыва:', _formatTime(_breakEnd)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRecordRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Информация о пользователе',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_user != null) ...[
              _buildUserInfoRow('ИНН:', _user!.id.toString()),
              const SizedBox(height: 12),
              _buildUserInfoRow('ОГРН:', _user!.company_id.toString()),
              const SizedBox(height: 12),
              _buildUserInfoRow('Отдел:', _user!.depart_id.toString().padLeft(3, '0')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}