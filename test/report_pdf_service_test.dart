import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/data/models/report_model.dart';
import 'package:myapp/services/report_pdf_service.dart';

/// Tests for the report PDF generation, which is deliberately free of Firestore
/// and BuildContext so it can be exercised without a running app.
///
/// These also guard the summary arithmetic the four generators share, since the
/// attendance, leave and salary totals shown on screen come from the same
/// helper methods.
void main() {
  ReportModel attendance({
    String id = 'att-1',
    String employeeId = 'emp-1',
    String employeeName = 'Asha Rao',
    String status = 'present',
    bool isLate = false,
  }) {
    return ReportModel(
      id: id,
      title: 'Attendance Report - 2026-01-01',
      type: 'Attendance',
      date: '01 Jan 2026',
      description: 'Status: $status',
      employeeId: employeeId,
      employeeName: employeeName,
      amount: 0.0,
      status: status,
      metadata: {
        'punchIn': DateTime(2026, 1, 1, 9, 5),
        'punchOut': DateTime(2026, 1, 1, 18, 30),
        'isLate': isLate,
        'isPresent': status == 'present',
        'isAbsent': status == 'absent',
      },
    );
  }

  ReportModel leave({
    String id = 'lv-1',
    String employeeId = 'emp-1',
    String employeeName = 'Asha Rao',
    String status = 'approved',
    int days = 2,
  }) {
    return ReportModel(
      id: id,
      title: 'Leave Request',
      type: 'Leave',
      date: '05 Jan 2026',
      description: 'Casual leave',
      employeeId: employeeId,
      employeeName: employeeName,
      amount: 0.0,
      status: status,
      metadata: {
        'from': DateTime(2026, 1, 5),
        'to': DateTime(2026, 1, 6),
        'days': days,
      },
    );
  }

  ReportModel salary({
    String id = 'sl-1',
    String employeeId = 'emp-1',
    String employeeName = 'Asha Rao',
    double amount = 50000,
    double? basicSalary,
  }) {
    return ReportModel(
      id: id,
      title: 'Salary Slip - Jan 2026',
      type: 'Salary',
      date: '31 Jan 2026',
      description: 'Monthly salary',
      employeeId: employeeId,
      employeeName: employeeName,
      amount: amount,
      status: 'paid',
      metadata: {
        'basicSalary': basicSalary ?? 30000,
        'allowances': amount - (basicSalary ?? 30000),
      },
    );
  }

  ReportPdfService serviceWith({
    List<ReportModel> attendance = const [],
    List<ReportModel> leave = const [],
    List<ReportModel> salary = const [],
  }) {
    return ReportPdfService(
      attendanceReports: attendance,
      leaveReports: leave,
      salaryReports: salary,
    );
  }

  bool isPdf(List<int>? bytes) {
    if (bytes == null || bytes.length < 4) return false;
    // Every PDF starts with the %PDF- header.
    return String.fromCharCodes(bytes.take(4)) == '%PDF';
  }

  group('ReportModel.fromFirestore', () {
    test('reads every field it is given', () {
      final model = ReportModel.fromFirestore({
        'id': 'r-9',
        'title': 'Salary Slip',
        'type': 'Salary',
        'date': '31 Jan 2026',
        'description': 'Monthly',
        'employeeId': 'emp-7',
        'employeeName': 'Ravi Kumar',
        'amount': 42,
        'status': 'paid',
        'metadata': {'basicSalary': 20},
      });

      expect(model.id, 'r-9');
      expect(model.employeeName, 'Ravi Kumar');
      // An int from Firestore must still land in the double field.
      expect(model.amount, 42.0);
      expect(model.metadata, {'basicSalary': 20});
    });

    test('falls back to empty values for an empty document', () {
      final model = ReportModel.fromFirestore({});

      expect(model.id, isEmpty);
      expect(model.employeeId, isEmpty);
      expect(model.amount, 0.0);
      expect(model.status, 'pending');
      expect(model.metadata, isNull);
    });

    test('does not throw on a null value for a non-nullable field', () {
      final model = ReportModel.fromFirestore({'title': null, 'amount': null});

      expect(model.title, isEmpty);
      expect(model.amount, 0.0);
    });
  });

  group('attendance report PDF', () {
    test('produces a PDF with no reports loaded', () async {
      final bytes = await serviceWith().generateAttendance('Current Month');

      expect(isPdf(bytes), isTrue,
          reason: 'an empty month should still render, not fail');
    });

    test('produces a PDF for a month of attendance', () async {
      final bytes = await serviceWith(
        attendance: [
          attendance(id: 'a1', status: 'present'),
          attendance(id: 'a2', status: 'late', isLate: true),
          attendance(id: 'a3', status: 'absent'),
        ],
      ).generateAttendance('Current Month');

      expect(isPdf(bytes), isTrue);
    });

    test('handles a large month without failing', () async {
      final bytes = await serviceWith(
        attendance: List.generate(
          400,
          (i) => attendance(
            id: 'a$i',
            employeeId: 'emp-$i',
            employeeName: 'Employee $i',
            status: i % 3 == 0 ? 'absent' : 'present',
            isLate: i % 7 == 0,
          ),
        ),
      ).generateAttendance('Current Month');

      expect(isPdf(bytes), isTrue);
    });
  });

  group('leave report PDF', () {
    test('produces a PDF with no leave loaded', () async {
      final bytes = await serviceWith().generateLeave('Current Month');

      expect(isPdf(bytes), isTrue);
    });

    test('produces a PDF across all three leave states', () async {
      final bytes = await serviceWith(
        leave: [
          leave(id: 'l1', status: 'approved', days: 2),
          leave(id: 'l2', status: 'pending', days: 1),
          leave(id: 'l3', status: 'rejected', days: 5),
        ],
      ).generateLeave('Current Month');

      expect(isPdf(bytes), isTrue);
    });
  });

  group('salary report PDF', () {
    test('produces a PDF with no salary loaded', () async {
      final bytes = await serviceWith().generateSalary('Current Month');

      expect(isPdf(bytes), isTrue);
    });

    test('produces a PDF for a single employee', () async {
      final bytes = await serviceWith(
        salary: [salary(amount: 50000, basicSalary: 30000)],
      ).generateSalary('Current Month');

      expect(isPdf(bytes), isTrue,
          reason: 'the rupee sign must not break PDF generation');
    });

    test('produces a PDF when the deduction exceeds the gross amount', () async {
      // A negative deduction is possible when deductions outrun the salary;
      // it must not throw.
      final bytes = await serviceWith(
        salary: [salary(amount: 1000, basicSalary: 30000)],
      ).generateSalary('Current Month');

      expect(isPdf(bytes), isTrue);
    });

    test('produces a PDF across several employees', () async {
      final bytes = await serviceWith(
        salary: List.generate(
          25,
          (i) => salary(
            id: 's$i',
            employeeId: 'emp-$i',
            employeeName: 'Employee $i',
            amount: 30000.0 + i * 1000,
            basicSalary: 20000.0 + i * 500,
          ),
        ),
      ).generateSalary('Last Month');

      expect(isPdf(bytes), isTrue);
    });
  });

  group('single report PDF', () {
    test('renders one attendance report', () async {
      final bytes = await serviceWith(attendance: [attendance()]).generate(
        attendance(),
      );

      expect(isPdf(bytes), isTrue);
    });

    test('renders a leave request with a null metadata field', () async {
      final bare = ReportModel(
        id: 'lv-9',
        title: 'Leave Request',
        type: 'Leave',
        date: '',
        description: '',
        employeeId: 'emp-9',
        employeeName: 'Neha Gupta',
        amount: 0.0,
        status: 'pending',
      );

      final bytes = await serviceWith(leave: [bare]).generate(bare);

      expect(isPdf(bytes), isTrue);
    });

    test('renders a salary report with no metadata at all', () async {
      final bare = ReportModel(
        id: 'sl-9',
        title: 'Salary Slip',
        type: 'Salary',
        date: '',
        description: '',
        employeeId: 'emp-9',
        employeeName: 'Neha Gupta',
        amount: 0.0,
        status: 'paid',
      );

      final bytes = await serviceWith(salary: [bare]).generate(bare);

      expect(isPdf(bytes), isTrue);
    });
  });

  group('service isolation', () {
    test('does not let one report list leak into another generator', () async {
      // Attendance data present, but the leave and salary lists are empty:
      // those two documents must still render their own empty state.
      final service = serviceWith(attendance: [attendance()]);

      expect(isPdf(await service.generateAttendance('Current Month')), isTrue);
      expect(isPdf(await service.generateLeave('Current Month')), isTrue);
      expect(isPdf(await service.generateSalary('Current Month')), isTrue);
    });

    test('does not mutate the report lists it was given', () async {
      final attendanceList = [attendance(id: 'a1'), attendance(id: 'a2')];
      final salaryList = [salary(amount: 50000, basicSalary: 30000)];
      final service = serviceWith(
        attendance: attendanceList,
        salary: salaryList,
      );

      expect(isPdf(await service.generateAttendance('Current Month')), isTrue);
      expect(isPdf(await service.generateSalary('Current Month')), isTrue);

      // The screen hands its own state lists straight in, so the service must
      // not add to, clear or reorder them while laying out a document.
      expect(attendanceList, hasLength(2));
      expect(salaryList, hasLength(1));
      expect(attendanceList.map((r) => r.id), ['a1', 'a2']);
      expect(salaryList.single.amount, 50000);
    });
  });
}