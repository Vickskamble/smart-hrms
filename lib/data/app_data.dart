class AppData {
  static List<Map<String, dynamic>> allEmployees = [
    {
      'name': 'Daksh Kumar',
      'id': 'GKH-101',
      'dept': 'Software',
      'salary': 30000,
      'absentDays': 2,
      'lateDays': 3,
      'status': 'Present',
      'phone': '9876543210',
      'inTime': '09:05 AM', 'outTime': null, // OUT missing
    },
    {
      'name': 'Rahul Singh', 'id': 'GKH-102', 'dept': 'QC', 'salary': 25000,
      'absentDays': 5, 'lateDays': 1, 'status': 'Absent', 'phone': '9123456789',
      'inTime': null, 'outTime': '06:00 PM', // IN missing
    },
    {
      'name': 'Amit Verma',
      'id': 'GKH-103',
      'dept': 'Production',
      'salary': 20000,
      'absentDays': 0,
      'lateDays': 0,
      'status': 'Present',
      'phone': '9988776655',
      'inTime': '08:50 AM', 'outTime': '05:30 PM', // Perfect Punch
    },
  ];

  static List<Map<String, dynamic>> leaveRequests = [
    {
      'empId': 'GKH-101',
      'name': 'Daksh Kumar',
      'reason': 'Medical Emergency',
      'date': '2026-04-20',
      'days': '2',
      'status': 'Pending',
    },
  ];

  // Counts for Dashboard
  static int get presentCount =>
      allEmployees.where((e) => e['status'] == 'Present').length;
  static int get absentCount =>
      allEmployees.where((e) => e['status'] == 'Absent').length;
  static int get lateCount =>
      allEmployees.where((e) => e['status'] == 'Late').length;

  static int get missedCount {
    return allEmployees
        .where(
          (e) =>
              (e['inTime'] != null && e['outTime'] == null) ||
              (e['inTime'] == null && e['outTime'] != null),
        )
        .length;
  }

  // Final Salary Logic
  static Map<String, dynamic> calculateDetailedSalary(
    Map<String, dynamic> emp,
  ) {
    double basic = double.tryParse(emp['salary']?.toString() ?? "0") ?? 0.0;
    int absent = emp['absentDays'] ?? 0;
    int late = emp['lateDays'] ?? 0;
    bool isMissed =
        (emp['inTime'] == null && emp['outTime'] != null) ||
        (emp['inTime'] != null && emp['outTime'] == null);

    double perDay = basic / 30;
    double absentFine = absent * perDay;
    double lateFine = (late ~/ 3) * (perDay * 0.5);
    double missedFine = isMissed ? (perDay * 0.5) : 0;

    double net = basic - (absentFine + lateFine + missedFine);

    return {
      'basic': basic.toStringAsFixed(0),
      'absentDeduction': absentFine.toStringAsFixed(0),
      'lateDeduction': lateFine.toStringAsFixed(0),
      'missedDeduction': missedFine.toStringAsFixed(0),
      'netSalary': net.toStringAsFixed(0),
    };
  }
}
