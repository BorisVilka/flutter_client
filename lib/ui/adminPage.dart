import 'package:flutter/material.dart';
//import 'package:flutter/system.dart';
import 'package:flutter/services.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:project_program/network/api_service.dart';
import 'package:project_program/entity/data/user.dart';
import 'package:project_program/entity/data/company.dart';
import 'package:project_program/entity/data/schedule.dart';
import 'package:project_program/entity/data/report_Item.dart';
import 'package:project_program/entity/data_list.dart';
import 'package:project_program/ui/addUserPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:project_program/theme/theme_manager.dart';

import '../network/constants.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  bool _isLoading = false;
  bool _showSearchError = false;
  User? _selectedUser;
  List<ReportItem> _reportItems = [];
  bool _isLoadingReports = false;

  @override
  void initState() {
    super.initState();
    _loadAllUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dataList = await ApiService.getUsers(null, null, null, null, null, null, null, null, _selectedUser?.company_id, null);
      setState(() {
        _allUsers.clear();
        _allUsers.addAll(dataList.data);
        _filteredUsers = List.from(_allUsers);
        _isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки пользователей: $e')),
        );
      }
    }
  }

  Future<void> _openAddUserPage() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddUserPage()),
    );
    
    if (result == true) {
      // Обновляем список пользователей после успешного добавления
      await _loadAllUsers();
    }
  }

  void _searchUser() {
    final innText = _searchController.text.trim();
    
    setState(() {
      if (innText.isEmpty) {
        _showSearchError = true;
        _selectedUser = null;
      } else {
        _showSearchError = false;
        if (!RegExp(r'^\d+$').hasMatch(innText)) {
          _selectedUser = null;
          return;
        }
        
        final inn = int.tryParse(innText);
        if (inn != null) {
          try {
            _selectedUser = _allUsers.firstWhere(
              (user) => user.id == inn,
            );
          } catch (e) {
            _selectedUser = null;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Пользователь не найден')),
              );
            }
          }
        }
      }
    });
  }

  Future<void> _assignManagerRole(User user) async {
    try {
      final response = await ApiService.editUser(
        user.id,
        null,
        null,
        null,
        null,
        'moderator',
        null,
        null,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: response.code == 200 ? Colors.green : Colors.red,
          ),
        );
        
        if (response.code == 200) {
          await _loadAllUsers();
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

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(Constants.token_tag_storage);
    Get.put("",tag: Constants.token_tag_storage);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Панель администратора',
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _logout();
            },
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Секция поиска пользователя
            _buildSearchSection(),
            const SizedBox(height: 24),
            // Секция всех пользователей
            _buildAllUsersSection(),
            const SizedBox(height: 24),
            // Секция управления ролями
            _buildRoleManagementSection(),
            const SizedBox(height: 24),
            // Секция отчетов
            _buildReportsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.search, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Поиск пользователя',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Введите ИНН для поиска пользователя в системе',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_showSearchError) ...[
              _buildErrorTooltip('Заполните это поле.'),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      if (_showSearchError && value.trim().isNotEmpty) {
                        setState(() {
                          _showSearchError = false;
                        });
                      }
                    },
                    decoration: InputDecoration(
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
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _searchUser,
                  icon: const Icon(Icons.search),
                  label: const Text('Найти'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedUser != null) ...[
              const SizedBox(height: 16),
              _buildUserDetailCard(_selectedUser!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAllUsersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Все пользователи системы',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _openAddUserPage,
                  tooltip: 'Добавить пользователя',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Список всех зарегистрированных пользователей',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_filteredUsers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('Пользователи не найдены'),
                ),
              )
            else
              ..._filteredUsers.map((user) => _buildUserCard(user)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(User user) {
    final fullName = '${user.last_name} ${user.first_name} ${user.patronymic}';
    final isManager = user.role == 'moderator';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    if (isManager) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'НО',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text('ИНН: ${user.id}'),
                Text('Отдел: ${user.depart_id.toString().padLeft(3, '0')}'),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedUser = user;
                _searchController.text = user.id.toString();
              });
            },
            child: const Text('Просмотр'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleManagementSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Управление ролями',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Информация о назначении статуса начальника отдела',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Как назначить начальника отдела:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('1. Найдите пользователя по ИНН'),
                  Text('2. Убедитесь, что у пользователя указан правильный ID отдела'),
                  Text('3. Нажмите кнопку "Выдать статус НО"'),
                  Text('4. Статус НО будет привязан к отделу, указанному в профиле пользователя'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Примечание:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Один пользователь может быть начальником только одного отдела. Статус НО автоматически привязывается к отделу, указанному в информации пользователя.',
                  ),
                ],
              ),
            ),
          ],
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

  String _getRoleName(String role) {
    switch (role) {
      case 'admin':
        return 'Админ';
      case 'moderator':
        return 'Начальник';
      case 'employee':
        return 'Сотрудник';
      default:
        return role;
    }
  }

  Widget _buildUserDetailCard(User user) {
    final fullName = '${user.last_name} ${user.first_name} ${user.patronymic}';
    final isManager = user.role == 'moderator';
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Полное имя
            Text(
              fullName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Две колонки с информацией
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Левая колонка
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('ИНН', user.id.toString()),
                      const SizedBox(height: 12),
                      _buildInfoRow('Отдел', user.depart_id.toString().padLeft(3, '0')),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Правая колонка
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('ОГРН', user.company_id.toString()),
                      const SizedBox(height: 12),
                      _buildInfoRow('Роль', _getRoleName(user.role)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Кнопки
            Row(
              children: [
                // Кнопка "Редактировать информацию"
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openEditUserDialog(user),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Редактировать информацию',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Кнопка "Выдать статус НО"
                if (!isManager)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _assignManagerRole(user),
                      icon: const Icon(Icons.people),
                      label: const Text(
                        'Выдать статус НО',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _openEditUserDialog(User user) async {
    await showDialog(
      context: context,
      builder: (context) => _EditUserDialog(
        user: user,
        onUserUpdated: () async {
          await _loadAllUsers();
          // Обновляем выбранного пользователя, если это он был отредактирован
          if (_selectedUser?.id == user.id) {
            final updatedUser = _allUsers.firstWhere(
              (u) => u.id == user.id,
              orElse: () => user,
            );
            setState(() {
              _selectedUser = updatedUser;
            });
          }
        },
      ),
    );
  }

  Widget _buildReportsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Отчеты по рабочему времени',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loadReports,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Обновить'),
                ),
              ],
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
    );
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoadingReports = true;
    });

    try {
      // Загружаем все отчеты
      final reportList = await ApiService.getJournalItems(
        null, // id
        null, // perPage
        null, // page
        null, // first_name
        null, // last_name
        null, // middle_name
        null, // depart_id
        null, // company_id
        null, // status
        null, // date
      );

      // Сортируем по дате (новые сверху)
      final reportItems = reportList.data.toList();
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
}

class _EditUserDialog extends StatefulWidget {
  final User user;
  final VoidCallback onUserUpdated;

  const _EditUserDialog({
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fioController;
  late TextEditingController _ogrnController;
  late TextEditingController _departmentIdController;
  
  List<Company> _companies = [];
  List<Schedule> _schedules = [];
  Company? _selectedCompany;
  Schedule? _selectedSchedule;
  String? _selectedRole = "user";
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _fioController = TextEditingController(
      text: '${widget.user.last_name} ${widget.user.first_name} ${widget.user.patronymic}',
    );
    _ogrnController = TextEditingController(text: widget.user.company_id.toString());
    _departmentIdController = TextEditingController(
      text: widget.user.depart_id.toString().padLeft(3, '0'),
    );
    _selectedRole = widget.user.role;
    _loadData();
  }

  @override
  void dispose() {
    _fioController.dispose();
    _ogrnController.dispose();
    _departmentIdController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final companies = await ApiService.getOrganizations(null, null, null, null);
      final schedules = await ApiService.geSchedules(null, null, null);
      
      setState(() {
        _companies = companies.data;
        _schedules = schedules.data;
        
        // Устанавливаем выбранные значения
        _selectedCompany = _companies.firstWhere(
          (c) => c.id == widget.user.company_id,
          orElse: () => _companies.isNotEmpty ? _companies.first : _companies.first,
        );
        _selectedSchedule = _schedules.firstWhere(
          (s) => s.id == widget.user.depart_id,
          orElse: () => _schedules.isNotEmpty ? _schedules.first : _schedules.first,
        );
        
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

  String _getRoleName(String role) {
    switch (role) {
      case 'admin':
        return 'Админ';
      case 'moderator':
        return 'Начальник';
      case 'user':
        return 'Сотрудник';
      default:
        return role;
    }
  }


  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCompany == null || _selectedSchedule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите организацию и отдел')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final fioParts = _parseFIO(_fioController.text.trim());
      
      final response = await ApiService.editUser(
        widget.user.id,
        fioParts[0], // last_name
        fioParts[2], // middle_name
        fioParts[1], // first_name
        _selectedSchedule!.id, // department_id
        _selectedRole, // role
        _selectedCompany!.id, // company_id
        _selectedSchedule!.id, // schedule_id
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
          widget.onUserUpdated();
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
                                'Редактировать информацию о пользователе',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.user.last_name} ${widget.user.first_name} ${widget.user.patronymic} (ИНН: ${widget.user.id})',
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
                    // Поле ФИО
                    TextFormField(
                      controller: _fioController,
                      decoration: InputDecoration(
                        labelText: 'ФИО',
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
                        final parts = value.trim().split(' ');
                        if (parts.length < 2) {
                          return 'Введите Фамилию Имя Отчество.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Выпадающий список ОГРН
                    DropdownButtonFormField<Company>(
                      value: _selectedCompany,
                      decoration: InputDecoration(
                        labelText: 'ОГРН',
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
                          if (value != null) {
                            _ogrnController.text = value.id.toString();
                          }
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
                          if (value != null) {
                            _departmentIdController.text = value.id.toString().padLeft(3, '0');
                          }
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
                    // Выпадающий список Роль
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Роль',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                      ),
                      items: const [
                        DropdownMenuItem<String>(
                          value: 'user',
                          child: Text('Сотрудник'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'moderator',
                          child: Text('Начальник'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'admin',
                          child: Text('Админ'),
                        ),
                      ],
                      onChanged: (String? value) {
                        setState(() {
                          _selectedRole = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    // Кнопки
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
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