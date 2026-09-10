import 'package:flutter/material.dart';
import '../../domain/reports_model.dart';

class EvaluationReportTable extends StatelessWidget {
  final List<EvaluationReportItem> items;
  const EvaluationReportTable({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Child ID')),
          DataColumn(label: Text('Child Name')),
          DataColumn(label: Text('Domain')),
          DataColumn(label: Text('Score')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Remarks')),
        ],
        rows: items.map((item) {
          return DataRow(cells: [
            DataCell(Text(item.childId)),
            DataCell(Text(item.childName)),
            DataCell(Text(item.domain)),
            DataCell(Text(item.score.toString())),
            DataCell(Text(item.date)),
            DataCell(Text(item.remarks)),
          ]);
        }).toList(),
      ),
    );
  }
}
