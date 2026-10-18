import 'package:flutter/material.dart';
import '../../domain/reports_model.dart';

class AttendanceReportTable extends StatelessWidget {
  final List<AttendanceReportItem> items;
  const AttendanceReportTable({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        dataRowMinHeight: 48,
        dataRowMaxHeight: 72,
        columns: const [
          DataColumn(label: Text('Child ID')),
          DataColumn(label: Text('Child Name')),
          DataColumn(label: Text('Present')),
          DataColumn(label: Text('Absent')),
          DataColumn(label: Text('Rate (%)')),
        ],
        rows: items.map((item) {
          return DataRow(cells: [
            DataCell(Text(item.childId)),
            DataCell(Text(item.childName)),
            DataCell(Text(item.present.toString())),
            DataCell(Text(item.absent.toString())),
            DataCell(Text('${item.attendanceRate.toStringAsFixed(1)}%')),
          ]);
        }).toList(),
      ),
    );
  }
}
