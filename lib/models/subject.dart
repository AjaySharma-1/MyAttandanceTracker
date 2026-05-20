import '../utils/id_utils.dart';
import 'attendance_record.dart';

class Subject {
  Subject({
    String? id,
    required this.name,
    required this.code,
    required this.instructor,
    this.targetPercentage = 75,
    required this.colorHex,
    List<AttendanceRecord>? records,
  })  : id = id ?? generateUuid(),
        records = records ?? <AttendanceRecord>[];

  final String id;
  String name;
  String code;
  String instructor;
  int targetPercentage;
  String colorHex;
  final List<AttendanceRecord> records;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'code': code,
        'instructor': instructor,
        'targetPercentage': targetPercentage,
        'colorHex': colorHex,
        'records': records.map((r) => r.toJson()).toList(),
      };

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'] as String?,
        name: (json['name'] as String?) ?? '',
        code: (json['code'] as String?) ?? '',
        instructor: (json['instructor'] as String?) ?? '',
        targetPercentage: (json['targetPercentage'] as num?)?.toInt() ?? 75,
        colorHex: (json['colorHex'] as String?) ?? '#1F4AA8',
        records: ((json['records'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic e) =>
                AttendanceRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
