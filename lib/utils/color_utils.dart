import 'package:flutter/material.dart';

Color colorFromHex(String hex) {
  final String value = hex.replaceAll('#', '');
  final String normalized = value.length == 6 ? 'FF$value' : value;
  return Color(int.parse(normalized, radix: 16));
}
