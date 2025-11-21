
import 'package:flutter/material.dart';

class Schedule {

  late int id;
  late TimeOfDay start;
  late TimeOfDay pause;
  late TimeOfDay end;
  late bool free;

  Schedule({
    required this.id,
    required this.start,
    required this.pause,
    required this.end,
    required this.free
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
        id: int.parse(json['count']),
        free: json['free'],
        start: TimeOfDay.fromDateTime(DateTime.parse(json['start'])),
        end: TimeOfDay(hour: 0,minute: 0),
        pause: TimeOfDay(hour: 0,minute: 0),
    );
  }
}