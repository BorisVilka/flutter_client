
import 'dart:convert';

import 'package:project_program/entity/data/company.dart';
import 'package:project_program/entity/data/journal_item.dart';
import 'package:project_program/entity/pagination.dart';
import 'package:project_program/entity/data/user.dart';

import 'data/schedule.dart';

class DataList<T> {

  late Pagination pagination;
  late int count;
  late List<T> data;

  DataList({required this.pagination, required this.data, required this.count});

  factory DataList.fromJson(Map<String, dynamic> json) {
    return DataList<T>(
      pagination: Pagination.fromJson(json['paginaton']),
      count: int.parse(json['count']),
      data: _parseData(json['data'], T) as List<T>
    );
  }

  static List _parseData(String source, Type type) {
    print(type);
    if(type==User) {
      final List<dynamic> data = json.decode(source);
      return data.map((json) => User.fromJson(json)).toList();
    } else if(type==Company) {
      final List<dynamic> data = json.decode(source);
      return data.map((json) => Company.fromJson(json)).toList();
    } else if(type==JournalItem) {
      final List<dynamic> data = json.decode(source);
      return data.map((json) => JournalItem.fromJson(json)).toList();
    } else if(type==Schedule) {
      final List<dynamic> data = json.decode(source);
      return data.map((json) => Schedule.fromJson(json)).toList();
    }
    return [];
  }
}