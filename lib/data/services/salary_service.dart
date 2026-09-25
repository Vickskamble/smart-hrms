import 'package:myapp/core/constants/app_constants.dart';

class SalaryService {
  static Map<String, dynamic> calculateDetailedSalary(Map<String, dynamic> emp) {
    final double basic = _parseDouble(emp['salary']);
    final int absent = _parseInt(emp['absentDays']);
    final int late = _parseInt(emp['lateDays']);
    final bool isMissed = _hasMissedPunch(emp);

    final double perDay = basic / AppConstants.workDaysPerMonth;
    final double absentFine = absent * perDay;
    final double lateFine = (late ~/ AppConstants.latePunchesPerDeduction) * (perDay * AppConstants.latePunchDeductionPercent);
    final double missedFine = isMissed ? (perDay * AppConstants.missedPunchDeductionPercent) : 0;

    final double net = basic - (absentFine + lateFine + missedFine);

    return {
      'basic': basic.toStringAsFixed(0),
      'absentDeduction': absentFine.toStringAsFixed(0),
      'lateDeduction': lateFine.toStringAsFixed(0),
      'missedDeduction': missedFine.toStringAsFixed(0),
      'netSalary': net.toStringAsFixed(0),
    };
  }

  static Map<String, dynamic> calculateMonthlySalary({
    required double basic,
    required int presentDays,
    required int missedPunches,
    required int totalDaysInMonth,
  }) {
    final double perDay = basic / totalDaysInMonth;
    final int absentDays = (totalDaysInMonth - presentDays - missedPunches).clamp(0, totalDaysInMonth);
    final double absentDeduction = absentDays * perDay;
    final double missedDeduction = missedPunches * (perDay * AppConstants.missedPunchDeductionPercent);
    final double netSalary = (basic - absentDeduction - missedDeduction).clamp(0, double.infinity);

    return {
      'basic': basic,
      'presentDays': presentDays,
      'absentDays': absentDays,
      'missedPunches': missedPunches,
      'perDay': perDay,
      'absentDeduction': absentDeduction,
      'missedDeduction': missedDeduction,
      'netSalary': netSalary,
    };
  }

  static Map<String, dynamic> calculateEmployeeExploreSalary(Map<String, dynamic> emp) {
    final double basic = _parseDouble(emp['salary']);
    final int absent = _parseInt(emp['absent']);
    final int missed = _parseInt(emp['missed']);

    final double absentDeduction = absent * 500;
    final double missedDeduction = missed * 200;
    final double net = basic - absentDeduction - missedDeduction;

    return {
      'basic': basic.toInt(),
      'absentDeduction': absentDeduction.toInt(),
      'missedDeduction': missedDeduction.toInt(),
      'netSalary': net.toInt(),
    };
  }

  static double _parseDouble(dynamic value) {
    return double.tryParse(value?.toString() ?? '0') ?? 0.0;
  }

  static int _parseInt(dynamic value) {
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  static bool _hasMissedPunch(Map<String, dynamic> emp) {
    final inTime = emp['inTime'];
    final outTime = emp['outTime'];
    return (inTime != null && outTime == null) || (inTime == null && outTime != null);
  }
}