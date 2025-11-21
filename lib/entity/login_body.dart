
class LoginBody {
  late int id;
  late String role;
  late String token;

  LoginBody({required this.id, required this.role, required this.token});

  factory LoginBody.fromJson(Map<String, dynamic> json) {
    return LoginBody(
      id: int.parse(json['id'].toString()),
      role: json['role'],
      token: json['token'],
    );
  }
}