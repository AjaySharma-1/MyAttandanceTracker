import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AttendanceTrackerApp());
}

const List<String> colorsHex = <String>[
  '#FF5A5F',
  '#2ECC71',
  '#1F4AA8',
  '#F4D03F',
  '#FF7F50',
  '#9B59B6',
  '#00A8A8',
  '#E67E22',
  '#E91E63',
  '#34495E',
];

class AttendanceTrackerApp extends StatelessWidget {
  const AttendanceTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Attendance',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const AttendanceHomePage(),
    );
  }
}

String generateUuid() {
  final math.Random random = math.Random();
  final int millis = DateTime.now().microsecondsSinceEpoch;
  String part(int n) =>
      List<int>.generate(n, (_) => random.nextInt(16)).map((v) => v.toRadixString(16)).join();
  return '${part(8)}-${part(4)}-4${part(3)}-${(8 + random.nextInt(4)).toRadixString(16)}${part(3)}-${millis.toRadixString(16).substring(0, 12)}';
}

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

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        id: json['id'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch((json['dateMs'] as num).toInt()),
        isPresent: (json['isPresent'] as bool?) ?? false,
        notes: (json['notes'] as String?) ?? '',
      );
}

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
            .map((dynamic e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AttendanceHomePage extends StatefulWidget {
  const AttendanceHomePage({super.key});

  @override
  State<AttendanceHomePage> createState() => _AttendanceHomePageState();
}

class _AttendanceHomePageState extends State<AttendanceHomePage> with TickerProviderStateMixin {
  static const String _prefsKey = 'subjects_db_v1';
  static const String _lastLowAttendanceReminderDateKey = 'last_low_attendance_reminder_date';
  late final TabController _tabController;
  final List<Subject> _subjects = <Subject>[];
  String _logFilterSubjectId = 'all';
  String _logStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    _subjects
      ..clear()
      ..addAll(list.map((dynamic e) => Subject.fromJson(e as Map<String, dynamic>)));
    if (mounted) setState(() {});
    _showLowAttendanceReminderIfNeeded();
  }

  Future<void> _saveSubjects() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = jsonEncode(_subjects.map((s) => s.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }

  String _todayKey() {
    final DateTime now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> _showLowAttendanceReminderIfNeeded({bool force = false}) async {
    if (!mounted) return;
    final List<Subject> lagging = _subjects.where((s) => _subjectPercent(s) < s.targetPercentage).toList();
    if (lagging.isEmpty) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String today = _todayKey();
    final String? lastReminder = prefs.getString(_lastLowAttendanceReminderDateKey);

    if (!force && lastReminder == today) return;

    if (!force) {
      await prefs.setString(_lastLowAttendanceReminderDateKey, today);
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Low Attendance Reminder'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('These subjects are currently below your target:'),
                const SizedBox(height: 10),
                ...lagging.take(4).map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${s.code}: ${_subjectPercent(s).toStringAsFixed(1)}% / target ${s.targetPercentage}%\n${_advisoryText(s)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    )),
                if (lagging.length > 4) Text('+${lagging.length - 4} more subject(s)'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _tabController.animateTo(0);
              },
              child: const Text('Review Dashboard'),
            ),
          ],
        );
      },
    );
  }

  bool _sameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _markAttendance(Subject subject, bool present) {
    final DateTime now = DateTime.now();
    final bool alreadyExists = subject.records.any((r) => _sameCalendarDay(r.date, now));
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance already recorded for this course today.'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }
    setState(() {
      subject.records.add(AttendanceRecord(date: now, isPresent: present));
    });
    _saveSubjects();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Checked in! You ${present ? "attended" : "missed"} ${subject.code} today.'),
      ),
    );
  }

  double _subjectPercent(Subject s) {
    if (s.records.isEmpty) return 0;
    final int attended = s.records.where((r) => r.isPresent).length;
    return (attended / s.records.length) * 100;
  }

  double _overallPercent() {
    int total = 0;
    int attended = 0;
    for (final Subject s in _subjects) {
      total += s.records.length;
      attended += s.records.where((r) => r.isPresent).length;
    }
    if (total == 0) return 0;
    return (attended / total) * 100;
  }

  String _advisoryText(Subject s) {
    final int conducted = s.records.length;
    final int attended = s.records.where((r) => r.isPresent).length;
    if (conducted == 0) return 'No lectures recorded yet.';
    final double currentRate = (attended / conducted) * 100;
    if (currentRate >= s.targetPercentage) {
      final double safe = ((100 * attended) - (s.targetPercentage * conducted)) / s.targetPercentage;
      final int safeToMiss = safe.floor();
      return 'Safe to skip next ${safeToMiss < 0 ? 0 : safeToMiss} class(es).';
    }
    final double numerator = (s.targetPercentage * conducted) - (100 * attended).toDouble();
    final double denominator = (100 - s.targetPercentage).toDouble();
    final int streak = denominator <= 0 ? 0 : (numerator / denominator).ceil();
    return 'Attend next $streak consecutively to hit ${s.targetPercentage}% target.';
  }

  Color _advisoryColor(Subject s) {
    return _subjectPercent(s) >= s.targetPercentage ? Colors.green.shade700 : Colors.red.shade700;
  }

  int get _overallConducted => _subjects.fold(0, (p, s) => p + s.records.length);
  int get _overallAttended => _subjects.fold(0, (p, s) => p + s.records.where((r) => r.isPresent).length);

  Future<void> _showCreateOrEditSubject({Subject? existing}) async {
    final TextEditingController nameCtl = TextEditingController(text: existing?.name ?? '');
    final TextEditingController codeCtl = TextEditingController(text: existing?.code ?? '');
    final TextEditingController teacherCtl = TextEditingController(text: existing?.instructor ?? '');
    int target = existing?.targetPercentage ?? 75;
    String selectedHex = existing?.colorHex ?? colorsHex.first;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(existing == null ? 'Register New Course' : 'Edit Course',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Subject Name')),
                    const SizedBox(height: 8),
                    TextField(controller: codeCtl, decoration: const InputDecoration(labelText: 'Course Code')),
                    const SizedBox(height: 8),
                    TextField(controller: teacherCtl, decoration: const InputDecoration(labelText: 'Instructor')),
                    const SizedBox(height: 12),
                    Text('Target: $target%', style: Theme.of(context).textTheme.titleMedium),
                    Slider(
                      value: target.toDouble(),
                      min: 50,
                      max: 100,
                      divisions: 50,
                      label: '$target%',
                      onChanged: (double v) => setModal(() => target = v.round()),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: colorsHex.map((hex) {
                        final bool selected = hex == selectedHex;
                        return GestureDetector(
                          onTap: () => setModal(() => selectedHex = hex),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorFromHex(hex),
                              border: Border.all(
                                color: selected ? Colors.black : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        if (nameCtl.text.trim().isEmpty || codeCtl.text.trim().isEmpty) return;
                        setState(() {
                          if (existing == null) {
                            _subjects.add(
                              Subject(
                                name: nameCtl.text.trim(),
                                code: codeCtl.text.trim(),
                                instructor: teacherCtl.text.trim(),
                                targetPercentage: target,
                                colorHex: selectedHex,
                              ),
                            );
                          } else {
                            existing
                              ..name = nameCtl.text.trim()
                              ..code = codeCtl.text.trim()
                              ..instructor = teacherCtl.text.trim()
                              ..targetPercentage = target
                              ..colorHex = selectedHex;
                          }
                        });
                        _saveSubjects();
                        Navigator.pop(ctx);
                      },
                      child: Text(existing == null ? 'Create Course' : 'Save Changes'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditRecordSheet(Subject subject, AttendanceRecord record) async {
    final TextEditingController noteCtl = TextEditingController(text: record.notes);
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Edit Attendance Record', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: () {
                      setState(() => record.date = record.date.subtract(const Duration(days: 1)));
                      _saveSubjects();
                    },
                    child: const Text('-1 day'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      setState(() => record.date = record.date.subtract(const Duration(days: 3)));
                      _saveSubjects();
                    },
                    child: const Text('-3 days'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      setState(() => record.date = record.date.subtract(const Duration(days: 7)));
                      _saveSubjects();
                    },
                    child: const Text('-7 days'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: record.date,
                      );
                      if (picked != null) {
                        setState(() => record.date = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              record.date.hour,
                              record.date.minute,
                            ));
                        _saveSubjects();
                      }
                    },
                    child: const Text('Pick date'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: record.isPresent,
                title: const Text('Marked Present'),
                onChanged: (bool value) {
                  setState(() => record.isPresent = value);
                  _saveSubjects();
                },
              ),
              TextField(
                controller: noteCtl,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Notes'),
                onChanged: (v) {
                  setState(() => record.notes = v);
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  FilledButton(
                    onPressed: () {
                      _saveSubjects();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Done'),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () {
                      setState(() => subject.records.removeWhere((r) => r.id == record.id));
                      _saveSubjects();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Delete record'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double overall = _overallPercent();
    return Scaffold(
      appBar: AppBar(
        title: Text('My Attendance • ${overall.toStringAsFixed(1)}%'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Low attendance reminder',
            onPressed: () => _showLowAttendanceReminderIfNeeded(force: true),
            icon: const Icon(Icons.notifications_active_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Tab>[
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.show_chart), text: 'Charts'),
            Tab(icon: Icon(Icons.list_alt), text: 'Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildDashboard(),
          _buildCharts(),
          _buildLogs(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrEditSubject(),
        icon: const Icon(Icons.add),
        label: const Text('Course'),
      ),
    );
  }

  Widget _buildDashboard() {
    final int missed = _overallConducted - _overallAttended;
    final int lagging = _subjects.where((s) => _subjectPercent(s) < s.targetPercentage).length;
    return RefreshIndicator(
      onRefresh: _loadSubjects,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          Card(
            color: lagging == 0 ? Colors.green.shade50 : Colors.orange.shade50,
            child: ListTile(
              leading: Icon(lagging == 0 ? Icons.celebration : Icons.warning_amber, size: 30),
              title: Text(lagging == 0
                  ? 'Great momentum! All subjects are on target.'
                  : '$lagging subject(s) are currently below target.'),
              subtitle: const Text('Stay consistent and review advisory hints.'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(child: _metricCard('Overall', '${_overallPercent().toStringAsFixed(1)}%')),
              const SizedBox(width: 8),
              Expanded(child: _metricCard('Checked', '$_overallAttended / $_overallConducted')),
              const SizedBox(width: 8),
              Expanded(child: _metricCard('Missed', '$missed')),
            ],
          ),
          const SizedBox(height: 12),
          if (_subjects.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No course yet. Tap + Course to begin.'),
              ),
            ),
          ..._subjects.map(_subjectCard),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            Text(title, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _subjectCard(Subject subject) {
    final int attended = subject.records.where((r) => r.isPresent).length;
    final int missed = subject.records.length - attended;
    final Color subjectColor = colorFromHex(subject.colorHex);
    final double percent = _subjectPercent(subject);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('${subject.code} • ${subject.name}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(subject.instructor),
                      const SizedBox(height: 4),
                      Text('Present: $attended  Absent: $missed'),
                    ],
                  ),
                ),
                SizedBox(
                  width: 84,
                  height: 84,
                  child: CustomPaint(
                    painter: RingProgressPainter(progressPercent: percent, color: subjectColor),
                    child: Center(
                      child: Text('${percent.toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _showCreateOrEditSubject(existing: subject);
                    if (v == 'delete') {
                      setState(() => _subjects.removeWhere((s) => s.id == subject.id));
                      _saveSubjects();
                    }
                    if (v == 'logs') {
                      setState(() {
                        _logFilterSubjectId = subject.id;
                      });
                      _tabController.animateTo(2);
                    }
                  },
                  itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                    PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                    PopupMenuItem<String>(value: 'logs', child: Text('Jump to logs')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _markAttendance(subject, true),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Attended'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _markAttendance(subject, false),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Absent'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _advisoryText(subject),
                style: TextStyle(color: _advisoryColor(subject), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharts() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Semester Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 240,
                  child: CustomPaint(
                    painter: TrendLinePainter(_subjects),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Course Comparison', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: math.max(170, (_subjects.length * 48).toDouble()),
                  child: CustomPaint(
                    painter: CourseBarChartPainter(_subjects),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogs() {
    final List<_LogItem> logs = <_LogItem>[];
    for (final Subject s in _subjects) {
      for (final AttendanceRecord r in s.records) {
        logs.add(_LogItem(subject: s, record: r));
      }
    }
    logs.sort((a, b) => b.record.date.compareTo(a.record.date));

    final List<_LogItem> filtered = logs.where((l) {
      final bool subjectMatch = _logFilterSubjectId == 'all' || l.subject.id == _logFilterSubjectId;
      final bool statusMatch = _logStatusFilter == 'all' ||
          (_logStatusFilter == 'present' && l.record.isPresent) ||
          (_logStatusFilter == 'absent' && !l.record.isPresent);
      return subjectMatch && statusMatch;
    }).toList();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _logFilterSubjectId,
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(value: 'all', child: Text('All Subjects')),
                    ..._subjects.map((s) => DropdownMenuItem<String>(value: s.id, child: Text(s.code))),
                  ],
                  onChanged: (v) => setState(() => _logFilterSubjectId = v ?? 'all'),
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _logStatusFilter,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(value: 'all', child: Text('All')),
                    DropdownMenuItem<String>(value: 'present', child: Text('Present')),
                    DropdownMenuItem<String>(value: 'absent', child: Text('Absent')),
                  ],
                  onChanged: (v) => setState(() => _logStatusFilter = v ?? 'all'),
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (BuildContext context, int i) {
              final _LogItem item = filtered[i];
              final AttendanceRecord r = item.record;
              final Subject s = item.subject;
              return ListTile(
                leading: CircleAvatar(backgroundColor: colorFromHex(s.colorHex), child: Text(s.code.substring(0, 2))),
                title: Text('${s.code} • ${s.name}'),
                subtitle: Text(
                  '${_dateLabel(r.date)} • ${r.isPresent ? "Present" : "Absent"}${r.notes.trim().isEmpty ? "" : " • ${r.notes}"}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_note),
                  onPressed: () => _showEditRecordSheet(s, r),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LogItem {
  const _LogItem({required this.subject, required this.record});
  final Subject subject;
  final AttendanceRecord record;
}

class RingProgressPainter extends CustomPainter {
  RingProgressPainter({required this.progressPercent, required this.color});
  final double progressPercent;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 5;

    final Paint base = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    canvas.drawCircle(center, radius, base);

    final Paint arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final double sweep = (progressPercent.clamp(0, 100) / 100) * 2 * math.pi;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant RingProgressPainter oldDelegate) {
    return oldDelegate.progressPercent != progressPercent || oldDelegate.color != color;
  }
}

class TrendLinePainter extends CustomPainter {
  TrendLinePainter(this.subjects);
  final List<Subject> subjects;

  @override
  void paint(Canvas canvas, Size size) {
    const double left = 42;
    const double right = 12;
    const double top = 16;
    const double bottom = 30;
    final Rect chart = Rect.fromLTWH(left, top, size.width - left - right, size.height - top - bottom);
    final Paint grid = Paint()..color = Colors.grey.shade300;
    for (int i = 0; i <= 5; i++) {
      final double y = chart.bottom - (chart.height * i / 5);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }
    for (int i = 0; i <= 5; i++) {
      final double x = chart.left + (chart.width * i / 5);
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), grid);
    }
    final List<AttendanceRecord> all = subjects.expand((s) => s.records).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (all.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(text: 'No data', style: TextStyle(color: Colors.black54)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2));
      return;
    }

    final Path line = Path();
    int present = 0;
    for (int i = 0; i < all.length; i++) {
      if (all[i].isPresent) present++;
      final double pct = (present / (i + 1)) * 100;
      final double x = chart.left + (chart.width * i / (all.length - 1 == 0 ? 1 : (all.length - 1)));
      final double y = chart.bottom - (chart.height * pct / 100);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = Colors.blue.shade700
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    final TextPainter yLabel = TextPainter(
      text: const TextSpan(text: 'Attendance %', style: TextStyle(color: Colors.black87, fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout();
    yLabel.paint(canvas, const Offset(4, 6));
  }

  @override
  bool shouldRepaint(covariant TrendLinePainter oldDelegate) => oldDelegate.subjects != subjects;
}

class CourseBarChartPainter extends CustomPainter {
  CourseBarChartPainter(this.subjects);
  final List<Subject> subjects;

  @override
  void paint(Canvas canvas, Size size) {
    const double left = 86;
    const double right = 16;
    const double top = 10;
    const double barHeight = 24;
    const double gap = 20;
    final double chartWidth = size.width - left - right;
    final Paint bg = Paint()..color = Colors.grey.shade200;
    final Paint targetLine = Paint()
      ..color = Colors.red.shade400
      ..strokeWidth = 1.5;

    for (int i = 0; i < subjects.length; i++) {
      final Subject s = subjects[i];
      final double pct = s.records.isEmpty
          ? 0
          : (s.records.where((r) => r.isPresent).length / s.records.length) * 100;
      final double y = top + i * (barHeight + gap);
      final Rect bgRect = Rect.fromLTWH(left, y, chartWidth, barHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(8)),
        bg,
      );
      final Rect fgRect = Rect.fromLTWH(left, y, chartWidth * (pct / 100), barHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(fgRect, const Radius.circular(8)),
        Paint()..color = colorFromHex(s.colorHex),
      );
      final double targetX = left + chartWidth * (s.targetPercentage / 100);
      canvas.drawLine(Offset(targetX, y - 2), Offset(targetX, y + barHeight + 2), targetLine);

      final TextPainter label = TextPainter(
        text: TextSpan(text: s.code, style: const TextStyle(color: Colors.black87, fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(10, y + 4));

      final TextPainter pctLabel = TextPainter(
        text: TextSpan(
          text: '${pct.toStringAsFixed(1)}%',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      pctLabel.paint(canvas, Offset(math.min(left + chartWidth - pctLabel.width, left + chartWidth * (pct / 100) + 6), y + 4));
    }
  }

  @override
  bool shouldRepaint(covariant CourseBarChartPainter oldDelegate) => oldDelegate.subjects != subjects;
}

Color colorFromHex(String hex) {
  final String value = hex.replaceAll('#', '');
  final String normalized = value.length == 6 ? 'FF$value' : value;
  return Color(int.parse(normalized, radix: 16));
}

String _dateLabel(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}
