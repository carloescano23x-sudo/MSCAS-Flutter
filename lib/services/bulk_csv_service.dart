import 'dart:convert';

import 'package:file_picker/file_picker.dart';

class BulkCsvResult {
  const BulkCsvResult({required this.fileName, required this.rows});

  final String fileName;
  final List<Map<String, String>> rows;
}

class BulkCsvService {
  static Future<BulkCsvResult?> pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw StateError('Unable to read the selected CSV file.');
    }
    final text = utf8.decode(bytes, allowMalformed: false);
    final table = _parse(text);
    if (table.isEmpty) {
      throw const FormatException('The CSV file is empty.');
    }
    final headers = table.first
        .map((value) => value.trim().toLowerCase())
        .toList(growable: false);
    if (headers.any((header) => header.isEmpty)) {
      throw const FormatException('CSV headers cannot be blank.');
    }
    final rows = <Map<String, String>>[];
    for (final values in table.skip(1)) {
      if (values.every((value) => value.trim().isEmpty)) continue;
      final row = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        row[headers[i]] = i < values.length ? values[i].trim() : '';
      }
      rows.add(row);
    }
    return BulkCsvResult(fileName: file.name, rows: rows);
  }

  static List<List<String>> _parse(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '"') {
        if (quoted && i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        row.add(field.toString());
        field = StringBuffer();
      } else if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
        row.add(field.toString());
        field = StringBuffer();
        if (row.any((value) => value.isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        field.write(char);
      }
    }
    if (quoted) throw const FormatException('CSV contains an unclosed quote.');
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      if (row.any((value) => value.isNotEmpty)) rows.add(row);
    }
    if (rows.isNotEmpty && rows.first.isNotEmpty) {
      rows[0][0] = rows[0][0].replaceFirst('\ufeff', '');
    }
    return rows;
  }
}
