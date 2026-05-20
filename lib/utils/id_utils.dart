import 'dart:math' as math;

String generateUuid() {
  final math.Random random = math.Random();
  final int millis = DateTime.now().microsecondsSinceEpoch;
  String part(int n) => List<int>.generate(n, (_) => random.nextInt(16))
      .map((v) => v.toRadixString(16))
      .join();
  return '${part(8)}-${part(4)}-4${part(3)}-${(8 + random.nextInt(4)).toRadixString(16)}${part(3)}-${millis.toRadixString(16).substring(0, 12)}';
}
