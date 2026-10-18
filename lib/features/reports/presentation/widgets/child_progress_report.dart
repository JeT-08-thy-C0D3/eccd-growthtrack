import 'package:flutter/material.dart';
import '../../domain/reports_model.dart';

class ChildProgressReportTable extends StatelessWidget {
  final List<ChildProgressReportItem> items;
  const ChildProgressReportTable({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = items.isEmpty
            ? [
                const DataRow(cells: [
                  DataCell(Text('No progress records yet')),
                  DataCell(SizedBox.shrink()),
                  DataCell(SizedBox.shrink()),
                  DataCell(SizedBox.shrink()),
                  DataCell(SizedBox.shrink()),
                  DataCell(SizedBox.shrink()),
                  DataCell(SizedBox.shrink()),
                ]),
              ]
            : items.map((item) {
                return DataRow(cells: [
                  DataCell(SizedBox(width: 130, child: Text(item.childId, maxLines: 1, overflow: TextOverflow.ellipsis))),
                  DataCell(SizedBox(width: 170, child: Text(item.childName, maxLines: 1, overflow: TextOverflow.ellipsis))),
                  DataCell(SizedBox(width: 170, child: Text(item.domain, maxLines: 2, overflow: TextOverflow.ellipsis))),
                  DataCell(Text(item.previousScore?.toString() ?? '-')),
                  DataCell(Text('${item.currentScore} / ${item.maxScore}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                  DataCell(SizedBox(width: 110, child: Text(item.developmentStatus ?? 'N/A', maxLines: 2, overflow: TextOverflow.ellipsis))),
                  DataCell(SizedBox(width: 220, child: Text(item.triangulatedSummary ?? 'N/A', maxLines: 2, overflow: TextOverflow.ellipsis))),
                ]);
              }).toList();

        final table = DataTable(
          horizontalMargin: 24,
          columnSpacing: 22,
          headingRowHeight: 56,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 72,
          dividerThickness: 0.7,
          columns: const [
            DataColumn(label: Text('Child ID')),
            DataColumn(label: Text('Child Name')),
            DataColumn(label: Text('Domain / Activity')),
            DataColumn(label: Text('Prev Score')),
            DataColumn(label: Text('Score / Max Score')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Triangulated Summary')),
          ],
          rows: rows,
        );

        // Center the Progress table like the reference layout, while keeping
        // horizontal scrolling available on narrow screens.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Align(
              alignment: Alignment.topCenter,
              child: table,
            ),
          ),
        );
      },
    );
  }
}
