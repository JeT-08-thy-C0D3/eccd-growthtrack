import 'package:flutter/material.dart';
import '../../domain/reports_model.dart';

class ReferralReportTable extends StatelessWidget {
  final List<ReferralReportItem> items;
  const ReferralReportTable({super.key, required this.items});

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
          DataColumn(label: Text('Concern')),
          DataColumn(label: Text('Referral Date')),
          DataColumn(label: Text('Follow-Up')),
          DataColumn(label: Text('Status')),
        ],
        rows: items.map((item) {
          return DataRow(cells: [
            DataCell(Text(item.childId)),
            DataCell(Text(item.childName)),
            DataCell(Text(item.concern)),
            DataCell(Text(item.referralDate)),
            DataCell(Text(item.followUpDate)),
            DataCell(Text(item.status)),
          ]);
        }).toList(),
      ),
    );
  }
}
