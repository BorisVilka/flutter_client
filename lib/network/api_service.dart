import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:project_program/entity/data/company.dart';
import 'package:project_program/entity/data/journal_item.dart';
import 'package:project_program/entity/data/schedule.dart';
import 'package:project_program/entity/login_body.dart';
import 'package:project_program/network/constants.dart';

import '../entity/answer.dart';
import '../entity/data_list.dart';
import '../entity/data/user.dart';

class ApiService {

  static const String baseUrl = 'http://127.0.0.1:20000';


  static Future<http.Response> _GET(String url) {
    return http.get(Uri.parse(url), headers: {
      'Authorization': Get.find(tag: Constants.token_tag_storage)
    });
  }

  static Future<http.Response> _POST(String url, String body) {
    return http.post(Uri.parse(url), headers: {
      'Authorization': Get.find(tag: Constants.token_tag_storage)
    },body: body);
  }

  static Future<http.Response> _PATCH(String url, String body) {
    return http.patch(Uri.parse(url), headers: {
      'Authorization': Get.find(tag: Constants.token_tag_storage),
        body: body
    });
  }

  static Future<http.Response> _PUT(String url, String body) {
    return http.put(Uri.parse(url), headers: {
      'Authorization': Get.find(tag: Constants.token_tag_storage),
      body: body
    });
  }

  static Future<http.Response> _DELETE(String url) {
    return http.delete(Uri.parse(url), headers: {
      'Authorization': Get.find(tag: Constants.token_tag_storage)
    });
  }

  ///POST

  static Future<LoginBody> login(String id, String pass) async {
    var body = {
      'inn': id,
      'password': pass
    };
    final response = await _POST("$baseUrl/auth/login",jsonEncode(body));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return LoginBody.fromJson(data);
    } else {
      throw Exception('Ошибка входа');
    }
  }

  static Future<Answer> registration(User user) async {
    var body = {
      'inn': user.id,
      'password': user.password,
      'last_name': user.last_name,
      'middle_name': user.patronymic,
      'firs_name': user.first_name,
      'department_id': user.depart_id,
      'company_ogrn': user.company_id
    };
    final response = await _POST("$baseUrl/auth/reg",jsonEncode(body));
    final Map<String, dynamic> data = json.decode(response.body);
    return Answer(message: data['message'],code: response.statusCode);
  }

  static Future<Answer> addCompany(String id, String name) async {
    var body = {
      'company_ogrn': id,
      'password': name
    };
    final response = await _POST("$baseUrl/add/company",jsonEncode(body));
    final Map<String, dynamic> data = json.decode(response.body);
    return Answer(message: data['message'],code: response.statusCode);
  }

  static Future<Answer> addSchedule(TimeOfDay start, TimeOfDay stop, TimeOfDay pause,Bool? free) async {
    var body = {
      'start': start.toString(),
      'stop': stop.toString(),
      'pause': pause.toString(),
      if(free!=null) 'free': free
    };
    final response = await _POST("$baseUrl/add/schedule",jsonEncode(body));
    final Map<String, dynamic> data = json.decode(response.body);
    return Answer(message: data['message'],code: response.statusCode);
  }

  ///GET

  static Future<DataList<Company>> getOrganizations(int? id, int? perPage, int? page, String? name) async {
    var url = "$baseUrl/dis/companies";
    var add = "";
    if(id!=null) add +="ogrn=$id";
    if(perPage!=null) add +="per_page=$perPage";
    if(page!=null) add +="page=$page";
    if(name!=null) add +="name=$name";
    if(add.isNotEmpty) url = "$url?$add";
    final response = await _GET(url);
    if(response.statusCode==200) {
      return DataList<Company>.fromJson(jsonDecode(response.body));
    } else {
      throw Exception();
    }
  }

  static Future<DataList<User>> getUsers(int? id, int? perPage, int? page,
      String? first_name, String? last_name, String? middle_name, int? depart_id, String? role, int? company_id, int? schedule_id) async {
    var url = "$baseUrl/dis/users";
    var add = "";
    if(id!=null) add +="inn=$id";
    if(perPage!=null) add +="per_page=$perPage";
    if(page!=null) add +="page=$page";
    if(first_name!=null) add +="first_name=$first_name";
    if(middle_name!=null) add +="middle_name=$middle_name";
    if(last_name!=null) add +="last_name=$last_name";
    if(role!=null) add +="role=$role";
    if(company_id!=null) add +="company_ogrn=$company_id";
    if(depart_id!=null) add +="schedule_id=$depart_id";
    if(add.isNotEmpty) url = "$url?$add";
    final response = await _GET(url);
    if(response.statusCode==200) {
      return DataList<User>.fromJson(jsonDecode(response.body));
    } else {
      throw Exception();
    }
  }

  static Future<DataList<JournalItem>> getJournalItemsByUser(int? user_id, int? id, int? perPage, int? page,
      String? first_name, String? last_name, String? middle_name, int? company_id, int? schedule_id, String? status, DateTime? date,
        String? note, TimeOfDay? start, TimeOfDay? end
      ) async {
    var url = "$baseUrl/journal/get";
    var add = "";
    if(id!=null) add +="inn=$id";
    if(perPage!=null) add +="per_page=$perPage";
    if(page!=null) add +="page=$page";
    if(first_name!=null) add +="first_name=$first_name";
    if(middle_name!=null) add +="middle_name=$middle_name";
    if(last_name!=null) add +="last_name=$last_name";
    if(company_id!=null) add +="user_company_ogrn=$company_id";
    if(schedule_id!=null) add +="user_schedule_id=$schedule_id";
    if(status!=null) add +="status=$status";
    if(date!=null) add +="date=$date";
    if(note!=null) add +="note=$note";
    if(start!=null) add +="start_time=$start";
    if(end!=null) add +="stop_time=$end";
    if(user_id!=null) add +="user_inn=$user_id";
    if(add.isNotEmpty) url = "$url?$add";
    final response = await _GET(url);
    if(response.statusCode==200) {
      return DataList<JournalItem>.fromJson(jsonDecode(response.body));
    } else {
      throw Exception();
    }
  }

  static Future<DataList<JournalItem>> getJournalItems(int? id, int? perPage, int? page,
      String? first_name, String? last_name, String? middle_name, int? depart_id, int? company_id, String? status, DateTime? date) async {
    var url = "$baseUrl/journal/get";
    var add = "";
    if(id!=null) add +="inn=$id";
    if(perPage!=null) add +="per_page=$perPage";
    if(page!=null) add +="page=$page";
    if(first_name!=null) add +="first_name=$first_name";
    if(middle_name!=null) add +="middle_name=$middle_name";
    if(last_name!=null) add +="last_name=$last_name";
    if(company_id!=null) add +="company_ogrn=$company_id";
    if(depart_id!=null) add +="schedule_id=$depart_id";
    if(status!=null) add +="status=$status";
    if(date!=null) add +="date=$date";
    if(add.isNotEmpty) url = "$url?$add";
    final response = await _GET(url);
    if(response.statusCode==200) {
      return DataList<JournalItem>.fromJson(jsonDecode(response.body));
    } else {
      throw Exception();
    }
  }

  static Future<DataList<Schedule>> geSchedules(int? perPage, int? page, bool? free) async {
    var url = "$baseUrl/dis/sch";
    var add = "";
    if(perPage!=null) add +="per_page=$perPage";
    if(page!=null) add +="page=$page";
    if(free!=null) add +="free=$free";
    if(add.isNotEmpty) url = "$url?$add";
    final response = await _GET(url);
    if(response.statusCode==200) {
      return DataList<Schedule>.fromJson(jsonDecode(response.body));
    } else {
      throw Exception();
    }
  }

  ///PUT

  static Future<Answer> addJournalItem(JournalItem item) async {
    final response = await _PATCH("$baseUrl/journal/put", jsonEncode(item));
    final Map<String, dynamic> data = json.decode(response.body);
    return Answer(message: data['message'],code: response.statusCode);
  }

  ///DEL

  static Future<Answer> deleteOrganization(String id) async {
    final response = await _DELETE("$baseUrl/del/company/$id");
    final Map<String, dynamic> data = json.decode(response.body);
    return Answer(message: data['message'],code: response.statusCode);
  }

  static Future<Answer> deleteJournal(String id) async {
    final response = await _DELETE("$baseUrl/del/journal/$id");
    final Map<String, dynamic> data = json.decode(response.body);
    return Answer(message: data['message'],code: response.statusCode);
  }

  static Future<Answer> deleteSchedule(String id) async {
    final response = await _GET("$baseUrl/del/schedule/$id");
    final Map<String, dynamic> data = json.decode(response.body);
    return Answer(message: data['message'],code: response.statusCode);
  }

  static Future<Answer> deleteUser(String id) async {
    final response = await _GET("$baseUrl/del/user/$id");
    final Map<String, dynamic> data = json.decode(response.body);
    return Answer(message: data['message'],code: response.statusCode);
  }

  ///PATCH

  static Future<Answer> editUser(int id, String? lastName, String? middleName,
      String? firstName, int? departmentId, String? role, int? companyId, int? scheduleId) async {
    final body = <String, dynamic>{
      'inn': id,
      if(lastName!=null) 'last_name': lastName,
      if(firstName!=null) 'first_name': firstName,
      if(middleName!=null) 'middle_name': middleName,
      if(departmentId !=null) 'department_id': departmentId,
      if(role !=null) 'role': role,
      if(companyId !=null) 'company_ogrn': companyId,
      if(scheduleId !=null) 'schedule_id': scheduleId ,
    };
    final response = await _PATCH("$baseUrl/patch/user",jsonEncode(body));
    final Map<String, dynamic> data = json.decode(response.body);
    return Answer(message: data['message'],code: response.statusCode);
  }

  static Future<Answer> editSchedule(int id, TimeOfDay? start, TimeOfDay? end, TimeOfDay? pause, bool? free) async {
    final body = <String, dynamic>{
      'id': id,
      if(start!=null) 'start': start,
      if(end!=null) 'stop': end,
      if(pause!=null) 'pause': pause,
      if(free!=null) 'free': free,
    };
    final response = await _PATCH("$baseUrl/patch/sch",jsonEncode(body));
    final Map<String, dynamic> data = json.decode(response.body);
    return Answer(message: data['message'],code: response.statusCode);
  }

  static Future<Answer> editNote(int id, String note) async {
    final body = <String, dynamic>{
      'id': id,
      'note': note
    };
    final response = await _PATCH("$baseUrl/patch/jour/note",jsonEncode(body));
    final Map<String, dynamic> data = json.decode(response.body);
    return Answer(message: data['message'],code: response.statusCode);
  }

  static Future<Answer> editCompany(int oldId, int? newId, String? name) async {
    final body = <String, dynamic>{
      'ogrn': oldId,
      if(newId !=null) 'new_orgn': newId,
      if(name !=null) 'new_name': name,
    };
    final response = await _PATCH("$baseUrl/patch/company",jsonEncode(body));
    final Map<String, dynamic> data = json.decode(response.body);
    return Answer(message: data['message'],code: response.statusCode);
  }

}