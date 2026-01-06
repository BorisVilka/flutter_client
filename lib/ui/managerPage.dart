import 'dart:math';

import 'package:flutter/material.dart';
import 'package:project_program/network/api_service.dart';
import 'package:project_program/entity/data/user.dart';
import 'package:project_program/entity/data/journal_item.dart';
import 'package:project_program/entity/data/schedule.dart';
import 'package:project_program/entity/data/report_Item.dart';
import 'package:project_program/entity/data_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_program/network/constants.dart';
import 'package:provider/provider.dart';
import 'package:project_program/theme/theme_manager.dart';

class ManagerPage extends StatefulWidget {
  final int userId;

  const ManagerPage({
    super.key,
    required this.userId,
  });

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  User? _user;
  JournalItem? _todayJournal;
  bool _isLoading = true;
  bool _isLoadingEmployees = false;
  bool _isLoadingReports = false;
  List<User> _departmentEmployees = [];
  List<ReportItem> _reportItems = [];
  String _currentStatus = 'Не начато';
  TimeOfDay? _workStart;
  TimeOfDay? _workEnd;
  TimeOfDay? _breakStart;
  TimeOfDay? _breakEnd;
  DateTime? _workDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _user != null) {
        // Обновляем список сотрудников при переключении на вкладку "Сотрудники"
        _loadDepartmentEmployees();
      } else if (_tabController.index == 2 && _user != null) {
        // Загружаем отчеты при переключении на вкладку "Отчеты"
        _loadReports();
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        // Загружаем сотрудников отдела
        await _loadDepartmentEmployees();
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
        pause: _breakStart ?? const TimeOfDay(hour: 0, minute: 0),
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

  Future<void> _loadDepartmentEmployees() async {
    if (_user == null) return;

    setState(() {
      _isLoadingEmployees = true;
    });

    try {
      final employeesList = await ApiService.getUsers(
        null, // id
        null, // perPage
        null, // page
        null, // first_name
        null, // last_name
        null, // middle_name
        _user!.depart_id, // depart_id
        'user', // role (сотрудники имеют роль user)
        null, // company_id
        null, // schedule_id
      );

      setState(() {
        // Фильтруем, чтобы исключить самого начальника
        _departmentEmployees = employeesList.data.where((u) => u.id != _user!.id).toList();
        _isLoadingEmployees = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingEmployees = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки сотрудников: $e')),
        );
      }
    }
  }

  Future<void> _deleteEmployee(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление сотрудника'),
        content: Text('Вы уверены, что хотите удалить сотрудника ${user.last_name} ${user.first_name} ${user.patronymic}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await ApiService.deleteUser(user.id.toString());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: response.code == 200 ? Colors.green : Colors.red,
            ),
          );

          if (response.code == 200) {
            await _loadDepartmentEmployees();
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
  }

  void _viewEmployee(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${user.last_name} ${user.first_name} ${user.patronymic}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ИНН: ${user.id}'),
            const SizedBox(height: 8),
            Text('ОГРН: ${user.company_id}'),
            const SizedBox(height: 8),
            Text('Отдел: ${user.depart_id.toString().padLeft(3, '0')}'),
            const SizedBox(height: 8),
            Text('Роль: ${user.role}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _editEmployee(User user) async {
    await showDialog(
      context: context,
      builder: (context) => _EditEmployeeDialog(
        employee: user,
        onEmployeeUpdated: _loadDepartmentEmployees,
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Constants.token_tag_storage);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final weekdays = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];
    final months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    return '$weekday, ${now.day} $month ${now.year} г.';
  }

  String get _userName {
    if (_user != null) {
      return '${_user!.last_name} ${_user!.first_name} ${_user!.patronymic}';
    }
    return 'Пользователь';
  }

  String get _departmentInfo {
    if (_user != null) {
      return 'Отдел ${_user!.depart_id.toString().padLeft(3, '0')}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Заголовок
                _buildHeader(),
                // Вкладки
                TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue,
                  tabs: const [
                    Tab(text: 'Моя работа'),
                    Tab(text: 'Сотрудники'),
                    Tab(text: 'Отчеты'),
                  ],
                ),
                // Содержимое вкладок
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMyWorkTab(),
                      _buildEmployeesTab(),
                      _buildReportsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).appBarTheme.backgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Панель начальника отдела',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_userName ($_departmentInfo)',
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
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Выйти'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyWorkTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Текущий статус
          _buildCurrentStatusCard(),
          const SizedBox(height: 16),
          // Управление рабочим временем
          _buildWorkTimeManagementCard(),
        ],
      ),
    );
  }

  Widget _buildEmployeesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.people, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Список сотрудников отдела ${_user?.depart_id.toString().padLeft(3, '0') ?? ''}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Управление сотрудниками вашего отдела',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoadingEmployees)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_departmentEmployees.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      'Сотрудники не найдены',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                )
              else
                _buildEmployeesTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeesTable() {
    return Table(
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey[300]!),
      ),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(2),
      },
      children: [
        // Заголовок таблицы
        TableRow(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          children: const [
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'ФИО',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'ИНН',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'ОГРН',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Действия',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        // Строки с данными сотрудников
        ..._departmentEmployees.asMap().entries.map((entry) {
          final index = entry.key;
          final employee = entry.value;
          final fullName = '${employee.last_name} ${employee.first_name} ${employee.patronymic}';
          final isLast = index == _departmentEmployees.length - 1;

          return TableRow(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
              borderRadius: isLast
                  ? const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    )
                  : null,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(fullName),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(employee.id.toString()),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(employee.company_id.toString()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility),
                      onPressed: () => _viewEmployee(employee),
                      tooltip: 'Просмотр',
                      color: Colors.blue,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _editEmployee(employee),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Изменить'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteEmployee(employee),
                      tooltip: 'Удалить',
                      color: Colors.red,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Отчет по рабочему времени',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Сводная таблица рабочего времени сотрудников',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoadingReports)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_reportItems.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      'Данные отсутствуют',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                )
              else
                _buildReportsTable(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadReports() async {
    if (_user == null) return;

    setState(() {
      _isLoadingReports = true;
    });

    try {
      // Загружаем отчеты для отдела через новый API
      final reportList = await ApiService.getJournalItems(
        null, // id
        null, // perPage
        null, // page
        null, // first_name
        null, // last_name
        null, // middle_name
        _user!.depart_id, // depart_id
        _user!.company_id, // company_id
        null, // status
        null, // date
      );

      // Фильтруем отчеты по отделу (если нужно)
      final reportItems = reportList.data.where((item) {
        return item.depart_id == _user!.depart_id;
      }).toList();

      // Сортируем по дате (новые сверху)
      reportItems.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _reportItems = reportItems;
        _isLoadingReports = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingReports = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки отчетов: $e')),
        );
      }
    }
  }

  Duration _calculateBreakDuration(TimeOfDay pause) {
    // pause - это время начала перерыва
    // Для планового перерыва используем стандартную длительность 1 час
    // Для фактического перерыва также используем 1 час, если перерыв был
    if (pause.hour == 0 && pause.minute == 0) {
      return const Duration(minutes: 0);
    }
    // Стандартная длительность перерыва - 1 час
    return const Duration(hours: 1, minutes: 0);
  }

  Duration _calculateFactBreakDuration(TimeOfDay? breakStart, TimeOfDay? breakEnd) {
    // Вычисляем фактическую длительность перерыва
    if (breakStart == null || breakEnd == null ||
        (breakStart.hour == 0 && breakStart.minute == 0) ||
        (breakEnd.hour == 0 && breakEnd.minute == 0)) {
      return const Duration(minutes: 0);
    }

    final startMinutes = breakStart.hour * 60 + breakStart.minute;
    final endMinutes = breakEnd.hour * 60 + breakEnd.minute;
    final diff = endMinutes - startMinutes;

    return Duration(minutes: diff > 0 ? diff : 0);
  }

  Duration _calculateWorkHours(TimeOfDay start, TimeOfDay end, Duration breakDuration) {
    if (end.hour == 0 && end.minute == 0) {
      return const Duration(minutes: 0);
    }

    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    final totalMinutes = endMinutes - startMinutes - breakDuration.inMinutes;

    return Duration(minutes: totalMinutes > 0 ? totalMinutes : 0);
  }

  String _determineStatus(TimeOfDay planStart, TimeOfDay factStart, TimeOfDay planEnd, TimeOfDay factEnd, Duration planBreak, Duration factBreak) {
    // Проверяем опоздание (более 15 минут)
    final startDiff = (factStart.hour * 60 + factStart.minute) - (planStart.hour * 60 + planStart.minute);
    if (startDiff > 15) {
      return 'ненорм';
    }

    // Проверяем ранний уход (более 15 минут)
    final endDiff = (planEnd.hour * 60 + planEnd.minute) - (factEnd.hour * 60 + factEnd.minute);
    if (endDiff > 15) {
      return 'ненорм';
    }

    // Проверяем перерыв (разница более 30 минут)
    final breakDiff = (factBreak.inMinutes - planBreak.inMinutes).abs();
    if (breakDiff > 30) {
      return 'ненорм';
    }

    return 'норм';
  }

  String _generateNote(TimeOfDay planStart, TimeOfDay factStart, TimeOfDay planEnd, TimeOfDay factEnd) {
    // Проверяем на наличие нулевых значений (TimeOfDay(hour: 0, minute: 0))
    if (factStart.hour == 0 && factStart.minute == 0) {
      return 'Работа не начата';
    }

    if (planStart.hour == 0 && planStart.minute == 0) {
      return 'График не установлен';
    }

    try {
      final startDiff = (factStart.hour * 60 + factStart.minute) - (planStart.hour * 60 + planStart.minute);

      if (startDiff > 15) {
        return 'Опоздание на ${startDiff} мин';
      } else if (startDiff < -15) {
        return 'Пришел на ${startDiff.abs()} мин раньше';
      } else if (startDiff > 0) {
        return 'Незначительное опоздание (${startDiff} мин)';
      } else if (startDiff < 0) {
        return 'Незначительное раннее прибытие (${startDiff.abs()} мин)';
      } else {
        return 'Прибыл вовремя';
      }
    } catch (e) {
      return 'Ошибка расчета времени';
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatEmployeeName(User user) {
    final lastName = user.last_name;
    final firstName = user.first_name.isNotEmpty ? user.first_name[0] : '';
    final patronymic = user.patronymic.isNotEmpty ? user.patronymic[0] : '';
    return '$lastName $firstName.$patronymic.';
  }

  Widget _buildReportsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(color: Colors.grey[300]!),
          verticalInside: BorderSide(color: Colors.grey[300]!),
        ),
        columnWidths: const {
          0: FixedColumnWidth(100),
          1: FixedColumnWidth(120),
          2: FixedColumnWidth(100),
          3: FixedColumnWidth(100),
          4: FixedColumnWidth(100),
          5: FixedColumnWidth(100),
          6: FixedColumnWidth(100),
          7: FixedColumnWidth(100),
          8: FixedColumnWidth(80),
          9: FixedColumnWidth(80),
          10: FixedColumnWidth(80),
          11: FixedColumnWidth(150),
        },
        children: [
          // Заголовок таблицы
          TableRow(
            decoration: BoxDecoration(
              color: Colors.grey[100],
            ),
            children: const [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Дата', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Сотрудник', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Начало (факт)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Начало (план)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Конец (факт)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Конец (план)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Перерыв (факт)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Перерыв (план)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Часы (факт)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Часы (план)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Статус', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Text('Заметка', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          // Строки с данными
          ..._reportItems.map((item) {
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_formatDate(item.date)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('${item.last_name} ${item.first_name.isNotEmpty ? item.first_name[0] : ''}.${item.patronymic.isNotEmpty ? item.patronymic[0] : ''}.'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_formatTime(item.start_schedule)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_formatTime(item.start)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_formatTime(item.end_schedule)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_formatTime(item.end)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_formatTime(item.pause)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_formatTime(item.pause_schedule)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_formatDuration(Duration(minutes: item.actual))),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_formatDuration(Duration(minutes: item.required))),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.status == 'норм' ? Colors.green[100] : Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.status,
                      style: TextStyle(
                        color: item.status == 'норм' ? Colors.green[800] : Colors.red[800],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(item.note),

                ),
              ],
            );
          }).toList(),
        ],
      ),
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
                  icon: const Icon(Icons.play_arrow),
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
                  icon: const Icon(Icons.stop),
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
}

class _EditEmployeeDialog extends StatefulWidget {
  final User employee;
  final VoidCallback onEmployeeUpdated;

  const _EditEmployeeDialog({
    required this.employee,
    required this.onEmployeeUpdated,
  });

  @override
  State<_EditEmployeeDialog> createState() => _EditEmployeeDialogState();
}

class _EditEmployeeDialogState extends State<_EditEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _departmentIdController = TextEditingController();

  List<Schedule> _schedules = [];
  Schedule? _selectedSchedule;
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _departmentIdController.text = widget.employee.depart_id.toString().padLeft(3, '0');
    _loadData();
  }

  @override
  void dispose() {
    _departmentIdController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final schedules = await ApiService.geSchedules(null, null, null);

      setState(() {
        _schedules = schedules.data;

        // Устанавливаем текущее расписание сотрудника
        try {
          _selectedSchedule = _schedules.firstWhere(
            (s) => s.id == widget.employee.schedule_id,
          );
        } catch (e) {
          _selectedSchedule = _schedules.isNotEmpty ? _schedules.first : null;
        }

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

  String _formatSchedule(Schedule schedule) {
    final start = '${schedule.start.hour.toString().padLeft(2, '0')}:${schedule.start.minute.toString().padLeft(2, '0')}';
    final end = '${schedule.end.hour.toString().padLeft(2, '0')}:${schedule.end.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSchedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите график работы')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final departmentId = int.tryParse(_departmentIdController.text.trim());
      if (departmentId == null) {
        throw Exception('Неверный ID отдела');
      }

      final response = await ApiService.editUser(
        widget.employee.id,
        null, // lastName
        null, // middleName
        null, // firstName
        departmentId, // departmentId
        null, // role
        null, // companyId
        _selectedSchedule!.id, // scheduleId
      );

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
          widget.onEmployeeUpdated();
          Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: _isLoadingData
          ? const Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(),
            )
          : Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок с кнопкой закрытия
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Изменить информацию о сотруднике',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.employee.last_name} ${widget.employee.first_name} ${widget.employee.patronymic}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Выпадающий список График работы
                    DropdownButtonFormField<Schedule>(
                      value: _selectedSchedule,
                      decoration: InputDecoration(
                        labelText: 'График работы',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                      ),
                      items: _schedules.map((schedule) {
                        return DropdownMenuItem<Schedule>(
                          value: schedule,
                          child: Text(_formatSchedule(schedule)),
                        );
                      }).toList(),
                      onChanged: (Schedule? value) {
                        setState(() {
                          _selectedSchedule = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Выберите график работы.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Поле ID отдела
                    TextFormField(
                      controller: _departmentIdController,
                      keyboardType: TextInputType.number,
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
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Заполните это поле.';
                        }
                        final id = int.tryParse(value.trim());
                        if (id == null) {
          return 'Введите корректный ID отдела.';
        }
        return null;
      },
    ),
    const SizedBox(height: 24),
    // Кнопки
    Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            side: BorderSide(color: Colors.grey[300]!),
          ),
          child: const Text(
            'Отмена',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveChanges,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 14,
            ),
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
                  'Сохранить',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ],
    ),
                  ],
                ),
              ),
      ),
    );
  }
}