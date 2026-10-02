import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';

class FileParser {
  static const int maxRowsPerFile = 500;
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB

  static Future<Map<String, dynamic>> parseFile(
    File file,
    String extension,
  ) async {
    try {
      final fileSize = await file.length();
      if (fileSize > maxFileSize) {
        throw Exception('File size exceeds 5MB limit');
      }

      if (extension == 'xlsx') {
        return _parseExcel(file);
      } else if (extension == 'csv') {
        return _parseCsv(file);
      } else {
        throw Exception('Unsupported file format');
      }
    } catch (e) {
      throw Exception('Failed to parse file: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> _parseExcel(File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) {
      throw Exception('Excel file is empty or invalid');
    }

    final sheet = excel.tables.values.first;
    final rows = <Map<String, dynamic>>[];

    for (var i = 0; i < sheet.maxRows; i++) {
      final rowData = <String, dynamic>{};
      bool hasData = false;

      for (var j = 0; j < sheet.maxColumns; j++) {
        final cellValue = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1)).value;
        if (cellValue != null) {
          final columnName = _getColumnName(j);
          rowData[columnName] = cellValue.toString().trim();
          hasData = true;
        }
      }

      if (hasData) {
        rows.add(rowData);
      }
    }

    if (rows.isEmpty) {
      throw Exception('No data found in Excel file');
    }

    return {
      'rows': rows,
      'totalRows': rows.length,
      'headers': _getExcelHeaders(sheet),
    };
  }

  static Future<Map<String, dynamic>> _parseCsv(File file) async {
    final content = await file.readAsString();
    final lines = LineSplitter.split(content).toList();

    if (lines.isEmpty) {
      throw Exception('CSV file is empty or invalid');
    }

    final headers = _parseCsvHeaders(lines.first);
    final rows = <Map<String, dynamic>>[];

    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;

      final values = _parseCsvLine(lines[i]);
      if (values.length < headers.length) {
        continue;
      }

      final rowData = <String, dynamic>{};
      for (var j = 0; j < headers.length; j++) {
        if (j < values.length) {
          rowData[headers[j]] = values[j].trim();
        }
      }

      rows.add(rowData);
    }

    if (rows.isEmpty) {
      throw Exception('No data found in CSV file');
    }

    return {
      'rows': rows,
      'totalRows': rows.length,
      'headers': headers,
    };
  }

  static String _getColumnName(int columnIndex) {
    final columnNames = [
      'name',
      'mobile',
      'email',
      'password',
      'department',
      'designation',
      'reportingManager',
      'gender',
      'bloodGroup',
      'address',
      'emergencyContact',
      'dateOfBirth',
      'dateOfJoining',
      'basicSalary',
    ];

    if (columnIndex < columnNames.length) {
      return columnNames[columnIndex];
    }

    return 'column_${columnIndex + 1}';
  }

  static List<String> _getExcelHeaders(Sheet sheet) {
    final headers = <String>{};

    for (var j = 0; j < sheet.maxColumns; j++) {
      final cellValue = sheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: 1)).value;
      if (cellValue != null) {
        final columnName = _getColumnName(j);
        headers.add(columnName);
      }
    }

    return headers.toList();
  }

  static List<String> _parseCsvHeaders(String line) {
    final values = <String>[];
    var current = '';
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
        current += char;
      } else if (char == ',' && !inQuotes) {
        values.add(current.trim());
        current = '';
      } else {
        current += char;
      }
    }

    if (current.isNotEmpty) {
      values.add(current.trim());
    }

    return values;
  }

  static List<String> _parseCsvLine(String line) {
    final values = <String>[];
    var current = '';
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
        current += char;
      } else if (char == ',' && !inQuotes) {
        values.add(current.trim());
        current = '';
      } else {
        current += char;
      }
    }

    if (current.isNotEmpty) {
      values.add(current.trim());
    }

    return values;
  }
}