import 'package:flutter/material.dart';

import '../../domain/reports_model.dart';

class AttendanceReportTable extends StatefulWidget {
  final List<AttendanceReportItem> items;
  final bool showScrollbars;

  const AttendanceReportTable({
    super.key,
    required this.items,
    this.showScrollbars = false,
  });

  @override
  State<AttendanceReportTable> createState() => _AttendanceReportTableState();
}

class _AttendanceReportTableState extends State<AttendanceReportTable> {
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
                DataColumn(label: Text('Present')),
                DataColumn(label: Text('Absent')),
                DataColumn(label: Text('Rate (%)')),
              ],
              rows: widget.items.map((item) {
                return DataRow(
                  cells: [
                    DataCell(Text(item.childId)),
                    DataCell(Text(item.childName)),
                    DataCell(Text(item.present.toString())),
                    DataCell(Text(item.absent.toString())),
                    DataCell(
                      Text('${item.attendanceRate.toStringAsFixed(1)}%'),
                    ),
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
