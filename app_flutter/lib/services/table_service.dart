import 'package:flutter/material.dart';

class TableService {
  static final TableService _instance = TableService._internal();
  factory TableService() => _instance;
  TableService._internal();

  final ValueNotifier<String?> tableIdNotifier = ValueNotifier(null);
  final ValueNotifier<String?> tableNumberNotifier = ValueNotifier(null);

  String? get tableId => tableIdNotifier.value;
  String? get tableNumber => tableNumberNotifier.value;

  void setTable(String id, String number) {
    tableIdNotifier.value = id;
    tableNumberNotifier.value = number;
  }
}
