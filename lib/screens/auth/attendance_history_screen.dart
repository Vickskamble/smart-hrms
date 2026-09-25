import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceHistoryScreen extends StatelessWidget {
  final String uid;
  const AttendanceHistoryScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Attendance Logs")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Attendance')
            .where('uid', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var logs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              var log = logs[index];
              return ListTile(
                leading: Icon(
                  Icons.circle,
                  color: log['type'] == "IN" ? Colors.green : Colors.red,
                ),
                title: Text("Punched ${log['type']}"),
                subtitle: Text("${log['date']} | ${log['time']}"),
              );
            },
          );
        },
      ),
    );
  }
}
