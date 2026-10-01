/// A single row in any of the employee report lists.
///
/// [fromFirestore] tolerates missing keys because attendance, leave and salary
/// documents are shaped differently by whichever code path wrote them.
class ReportModel {
  final String id;
  final String title;
  final String type;
  final String date;
  final String description;
  final String employeeId;
  final String employeeName;
  final double amount;
  final String status;
  final Map<String, dynamic>? metadata;

  ReportModel({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    required this.description,
    required this.employeeId,
    required this.employeeName,
    required this.amount,
    required this.status,
    this.metadata,
  });

  factory ReportModel.fromFirestore(Map<String, dynamic> data) {
    return ReportModel(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      type: data['type'] ?? '',
      date: data['date'] ?? '',
      description: data['description'] ?? '',
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      status: data['status'] ?? 'pending',
      metadata: data['metadata'],
    );
  }
}