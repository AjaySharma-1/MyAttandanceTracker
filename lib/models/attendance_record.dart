import '../utils/id_utils.dart';

class AttendanceRecord {
  AttendanceRecord({
    String? id,
    required this.date,
    required this.isPresent,
    this.notes = '',
  }) : id = id ?? generateUuid();

  final String id;
  DateTime date;
  bool isPresent;
  String notes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'dateMs': date.millisecondsSinceEpoch,
        'isPresent': isPresent,
        'notes': notes,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: json['id'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(
            (json['dateMs'] as num).toInt()),
        isPresent: (json['isPresent'] as bool?) ?? false,
        notes: (json['notes'] as String?) ?? '',
      );
}
