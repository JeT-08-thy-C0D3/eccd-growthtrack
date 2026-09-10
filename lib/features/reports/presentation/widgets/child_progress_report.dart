import 'package:flutter/material.dart';
import '../../domain/reports_model.dart';

class ChildProgressReportTable extends StatelessWidget {
  final List<ChildProgressReportItem> items;
  const ChildProgressReportTable({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Child ID')),
          DataColumn(label: Text('Child Name')),
          DataColumn(label: Text('Domain')),
          DataColumn(label: Text('Prev Score')),
          DataColumn(label: Text('Curr Score')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Triangulated Summary')),
        ],
        rows: items.map((item) {
          return DataRow(cells: [
            DataCell(Text(item.childId)),
            DataCell(Text(item.childName)),
            DataCell(Text(item.domain)),
            DataCell(Text(item.previousScore?.toString() ?? '-')),
            DataCell(Text(item.currentScore.toString())),
            DataCell(Text(item.developmentStatus ?? 'N/A')),
            DataCell(Text(item.triangulatedSummary ?? 'N/A')),
          ]);
        }).toList(),
      ),
    );
  }
}
