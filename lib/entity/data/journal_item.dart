
import 'package:flutter/material.dart';

class JournalItem {

  late int id;
  late TimeOfDay start;
  late TimeOfDay pause;
  late TimeOfDay end;
  late String status;
  late String note;
  late int user_inn;
  late int company_id;
  late int schedule_id;
  late DateTime date;

  JournalItem({
    required this.id,
    required this.start,
    required this.pause,
    required this.end,
    required this.status,
    required this.note,
    required this.schedule_id,
    required this.company_id,
    required this.user_inn,
    required this.date
  });

  factory JournalItem.fromJson(Map<String, dynamic> json) {
    return JournalItem(
      id: int.parse(json['count']),
      start: TimeOfDay.fromDateTime(DateTime.parse(json['start'])),
      end: TimeOfDay(hour: 0,minute: 0),
      pause: TimeOfDay(hour: 0,minute: 0),
      status: json['status'],
      note: json['note'],
      user_inn: int.parse(json['user_inn']),
      company_id: int.parse(json['company_id']),
      schedule_id: int.parse(json['schedule_id']),
      date: DateTime.parse(json['date'])
    );
  }

}