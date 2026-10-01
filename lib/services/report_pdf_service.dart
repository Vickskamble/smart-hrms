import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:myapp/data/models/report_model.dart';

/// Builds the PDF documents offered on the employee reports screen.
///
/// This is pure formatting over already-loaded [ReportModel] lists: it touches no
/// Firestore, no BuildContext and no widget state, so it can be exercised without
/// a running app. Construct it with the three lists to render.
class ReportPdfService {
  final List<ReportModel> attendanceReports;
  final List<ReportModel> leaveReports;
  final List<ReportModel> salaryReports;

  ReportPdfService({
    required this.attendanceReports,
    required this.leaveReports,
    required this.salaryReports,
  });
  // ── Generate attendance PDF for specific period ─────────────────────────────────
  Future<List<int>?> generateAttendance(String period) async {
    try {
      final pdfDoc = pw.Document();

      // Add report header
      pdfDoc.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Smart HRMS",
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Attendance Report",
                          style: const pw.TextStyle(
                            fontSize: 16,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          period,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          DateFormat('dd MMM yyyy').format(DateTime.now()),
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Summary cards
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAttendanceSummaryCard(
                      "Total Employees",
                      attendanceReports.length.toString(),
                      PdfColors.blue900,
                    ),
                    _buildAttendanceSummaryCard(
                      "Present",
                      _calculatePresentCount().toString(),
                      PdfColors.green,
                    ),
                    _buildAttendanceSummaryCard(
                      "Absent",
                      _calculateAbsentCount().toString(),
                      PdfColors.red,
                    ),
                    _buildAttendanceSummaryCard(
                      "Late",
                      _calculateLateCount().toString(),
                      PdfColors.orange,
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Attendance details
                pw.Text(
                  "Employee Attendance Details",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 12),

                // Table header
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "Employee Name",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "Date",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "Status",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "Punch In",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "Punch Out",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Attendance rows
                ...attendanceReports
                    .map(
                      (report) => pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey200),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              flex: 3,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  report.employeeName,
                                  style: const pw.TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  report.date,
                                  style: const pw.TextStyle(fontSize: 11),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: pw.BoxDecoration(
                                    color: report.status == 'present'
                                        ? const PdfColor(0, 1, 0, 0.1)
                                        : report.status == 'absent'
                                            ? const PdfColor(1, 0, 0, 0.1)
                                            : const PdfColor(1, 1, 0, 0.1),
                                    borderRadius: pw.BorderRadius.circular(4),
                                  ),
                                  child: pw.Text(
                                    report.status.toUpperCase(),
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: report.status == 'present'
                                          ? PdfColors.green
                                          : report.status == 'absent'
                                              ? PdfColors.red
                                              : PdfColors.orange,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  report.metadata?['punchInTime'] != null
                                      ? _formatDateForPDF(report.metadata!['punchInTime'])
                                      : 'N/A',
                                  style: const pw.TextStyle(fontSize: 11),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  report.metadata?['punchOutTime'] != null
                                      ? _formatDateForPDF(report.metadata!['punchOutTime'])
                                      : 'N/A',
                                  style: const pw.TextStyle(fontSize: 11),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    ,

                // Footer
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 30),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        "Generated on ${DateTime.now().toString()}",
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Return PDF bytes
      return pdfDoc.save();
    } catch (e) {
      debugPrint('Error generating attendance PDF: $e');
      return null;
    }
  }

  // ── Generate leave PDF for specific period ───────────────────────────────────────
  Future<List<int>?> generateLeave(String period) async {
    try {
      final pdfDoc = pw.Document();

      // Add report header
      pdfDoc.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Smart HRMS",
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Leave Report",
                          style: const pw.TextStyle(
                            fontSize: 16,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          period,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          DateFormat('dd MMM yyyy').format(DateTime.now()),
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Summary cards
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildLeaveSummaryCard(
                      "Total Leave Requests",
                      leaveReports.length.toString(),
                      PdfColors.blue900,
                    ),
                    _buildLeaveSummaryCard(
                      "Approved",
                      _calculateApprovedCount().toString(),
                      PdfColors.green,
                    ),
                    _buildLeaveSummaryCard(
                      "Pending",
                      _calculatePendingCount().toString(),
                      PdfColors.orange,
                    ),
                    _buildLeaveSummaryCard(
                      "Rejected",
                      _calculateRejectedCount().toString(),
                      PdfColors.red,
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Leave details
                pw.Text(
                  "Employee Leave Details",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 12),

                // Table header
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "Employee Name",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "Type",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "Days",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "From",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "To",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "Status",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Leave rows
                ...leaveReports
                    .map(
                      (report) => pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey200),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              flex: 3,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  report.employeeName,
                                  style: const pw.TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  report.metadata?['type'] ?? '',
                                  style: const pw.TextStyle(fontSize: 11),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  report.description.split(' - ')[0],
                                  style: const pw.TextStyle(fontSize: 11),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  report.metadata?['from'] != null
                                      ? _formatDateForPDF(report.metadata!['from'])
                                      : 'N/A',
                                  style: const pw.TextStyle(fontSize: 11),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  report.metadata?['to'] != null
                                      ? _formatDateForPDF(report.metadata!['to'])
                                      : 'N/A',
                                  style: const pw.TextStyle(fontSize: 11),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: pw.BoxDecoration(
                                    color: report.status == 'approved'
                                        ? const PdfColor(0, 1, 0, 0.1)
                                        : report.status == 'pending'
                                            ? const PdfColor(1, 1, 0, 0.1)
                                            : const PdfColor(1, 0, 0, 0.1),
                                    borderRadius: pw.BorderRadius.circular(4),
                                  ),
                                  child: pw.Text(
                                    report.status.toUpperCase(),
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: report.status == 'approved'
                                          ? PdfColors.green
                                          : report.status == 'pending'
                                              ? PdfColors.orange
                                              : PdfColors.red,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    ,

                // Footer
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 30),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        "Generated on ${DateTime.now().toString()}",
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Return PDF bytes
      return pdfDoc.save();
    } catch (e) {
      debugPrint('Error generating leave PDF: $e');
      return null;
    }
  }

  // ── Generate salary PDF for specific period ───────────────────────────────────
  Future<List<int>?> generateSalary(String period) async {
    try {
      final pdfDoc = pw.Document();

      // Add report header
      pdfDoc.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Smart HRMS",
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Salary Report",
                          style: const pw.TextStyle(
                            fontSize: 16,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          period,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          DateFormat('dd MMM yyyy').format(DateTime.now()),
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Summary cards
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSalarySummaryCard(
                      "Total Employees",
                      salaryReports.length.toString(),
                      PdfColors.blue900,
                    ),
                    _buildSalarySummaryCard(
                      "Total Salary",
                      _calculateTotalSalary().toStringAsFixed(0),
                      PdfColors.green,
                    ),
                    _buildSalarySummaryCard(
                      "Average Salary",
                      _calculateAverageSalary().toStringAsFixed(0),
                      PdfColors.orange,
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Salary details
                pw.Text(
                  "Employee Salary Details",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 12),

                // Table header
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "Employee Name",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "Basic Salary",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "Net Salary",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "Deductions",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Salary rows
                ...salaryReports
                    .map(
                      (report) => pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey200),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              flex: 3,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  report.employeeName,
                                  style: const pw.TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  "₹${report.metadata?['basicSalary']?.toStringAsFixed(0) ?? '0'}",
                                  style: const pw.TextStyle(fontSize: 11),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  "₹${report.amount.toStringAsFixed(0)}",
                                  style: const pw.TextStyle(fontSize: 11),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  "₹${(report.amount - (report.metadata?['basicSalary'] ?? 0)).toStringAsFixed(0)}",
                                  style: const pw.TextStyle(fontSize: 11),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    ,

                // Footer
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 30),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        "Generated on ${DateTime.now().toString()}",
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Return PDF bytes
      return pdfDoc.save();
    } catch (e) {
      debugPrint('Error generating salary PDF: $e');
      return null;
    }
  }

  // ── Helper: Calculate total salary ───────────────────────────────────────────
  double _calculateTotalSalary() {
    return salaryReports.fold(0.0, (sumValue, report) => sumValue + report.amount);
  }

  // ── Helper: Calculate average salary ────────────────────────────────────────
  double _calculateAverageSalary() {
    if (salaryReports.isEmpty) return 0.0;
    return _calculateTotalSalary() / salaryReports.length;
  }

  // ── Helper: Calculate present count ──────────────────────────────────────────
  int _calculatePresentCount() {
    int count = 0;
    for (final report in attendanceReports) {
      if (report.status == 'present') count++;
    }
    return count;
  }

  // ── Helper: Calculate absent count ──────────────────────────────────────────
  int _calculateAbsentCount() {
    int count = 0;
    for (final report in attendanceReports) {
      if (report.status == 'absent') count++;
    }
    return count;
  }

  // ── Helper: Calculate late count ───────────────────────────────────────────
  int _calculateLateCount() {
    int count = 0;
    for (final report in attendanceReports) {
      if (report.metadata?['isLate'] == true) count++;
    }
    return count;
  }

  // ── Helper: Calculate approved count ────────────────────────────────────────
  int _calculateApprovedCount() {
    int count = 0;
    for (final report in leaveReports) {
      if (report.status == 'approved') count++;
    }
    return count;
  }

  // ── Helper: Calculate pending count ─────────────────────────────────────────
  int _calculatePendingCount() {
    int count = 0;
    for (final report in leaveReports) {
      if (report.status == 'pending') count++;
    }
    return count;
  }

  // ── Helper: Calculate rejected count ───────────────────────────────────────
  int _calculateRejectedCount() {
    int count = 0;
    for (final report in leaveReports) {
      if (report.status == 'rejected') count++;
    }
    return count;
  }

  // ── Helper: Format date for PDF ─────────────────────────────────────────────
  String _formatDateForPDF(dynamic date) {
    if (date == null) return '';
    if (date is DateTime) {
      return DateFormat('dd MMM yyyy').format(date);
    }
    if (date is Timestamp) {
      return DateFormat('dd MMM yyyy').format(date.toDate());
    }
    return date.toString();
  }

  // ── Helper: Build attendance summary card ─────────────────────────────────────
  pw.Widget _buildAttendanceSummaryCard(
    String title,
    String value,
    PdfColor color,
  ) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor(color.red, color.green, color.blue, 0.1),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: PdfColor(color.red, color.green, color.blue, 0.3),
        ),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Helper: Build leave summary card ─────────────────────────────────────────
  pw.Widget _buildLeaveSummaryCard(
    String title,
    String value,
    PdfColor color,
  ) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor(color.red, color.green, color.blue, 0.1),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: PdfColor(color.red, color.green, color.blue, 0.3),
        ),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Helper: Build salary summary card ────────────────────────────────────────
  pw.Widget _buildSalarySummaryCard(
    String title,
    String value,
    PdfColor color,
  ) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor(color.red, color.green, color.blue, 0.1),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: PdfColor(color.red, color.green, color.blue, 0.3),
        ),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Generate PDF report ────────────────────────────────────────────────────
  Future<List<int>?> generate(ReportModel report) async {
    try {
      final pdf = pw.Document();

      // Add report header
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Smart HRMS",
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Employee Report",
                          style: const pw.TextStyle(
                            fontSize: 16,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          report.date,
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Report ID: ${report.id}",
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Report details
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        report.title,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      _buildPDFDetailRow("Employee", report.employeeName),
                      _buildPDFDetailRow("Type", report.type),
                      _buildPDFDetailRow("Status", report.status),
                      if (report.type == 'Salary') ...[
                        _buildPDFDetailRow(
                          "Amount",
                          "₹${report.amount.toStringAsFixed(0)}",
                        ),
                      ],
                      _buildPDFDetailRow("Description", report.description),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Employee information
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Employee Information",
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      _buildPDFDetailRow("Employee ID", report.employeeId),
                    ],
                  ),
                ),

                // Footer
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 30),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        "Generated on ${DateTime.now().toString()}",
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Return PDF bytes
      return pdf.save();
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      return null;
    }
  }

  pw.Widget _buildPDFDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

