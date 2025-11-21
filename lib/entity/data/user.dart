
class User {

  late int id;
  late int depart_id;
  late String first_name;
  late String last_name;
  late String patronymic;
  late int company_id;
  late int schedule_id;
  late String role;
  late String password;

  User({
    required this.id,
    required this.company_id,
    required this.depart_id,
    required this.schedule_id,
    required this.first_name,
    required this.last_name,
    required this.patronymic,
    required this.role,
    required this.password
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: int.parse(json['inn'].toString()),
      company_id: int.parse(json['company_ogrn'].toString()),
      depart_id: int.parse(json['department_id'].toString()),
      schedule_id: int.parse(json['schedule_id'].toString()),
      first_name: json['first_name'],
      last_name: json['last_name'],
      patronymic: json['middle_name'],
      role: json['role'],
      password: json['password']
    );
  }

}