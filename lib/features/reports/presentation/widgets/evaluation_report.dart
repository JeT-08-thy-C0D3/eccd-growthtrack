import 'package:flutter/material.dart';

import '../../domain/reports_model.dart';

class EvaluationReportTable extends StatefulWidget {
  final List<EvaluationReportItem> items;
  final bool showScrollbars;

  const EvaluationReportTable({
    super.key,
    required this.items,
    this.showScrollbars = false,
  });

  @override
  State<EvaluationReportTable> createState() => _EvaluationReportTableState();
}

class _EvaluationReportTableState extends State<EvaluationReportTable> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: widget.showScrollbars,
      trackVisibility: widget.showScrollbars,
      child: SingleChildScrollView(
        controller: _verticalController,
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: widget.showScrollbars,
          trackVisibility: widget.showScrollbars,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 48,
              dataRowMaxHeight: 72,
              columns: const [
                DataColumn(label: Text('Child ID')),
                DataColumn(label: Text('Child Name')),
                DataColumn(label: Text('Domain')),
                DataColumn(label: Text('Score')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Remarks')),
              ],
              rows: widget.items.map((item) {
                return DataRow(
                  cells: [
                    DataCell(Text(item.childId)),
                    DataCell(Text(item.childName)),
                    DataCell(Text(item.domain)),
                    DataCell(Text(item.score.toString())),
                    DataCell(Text(item.date)),
                    DataCell(Text(item.remarks)),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
