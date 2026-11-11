import 'package:flutter/material.dart';

import '../../domain/reports_model.dart';

class ReferralReportTable extends StatefulWidget {
  final List<ReferralReportItem> items;
  final bool showScrollbars;

  const ReferralReportTable({
    super.key,
    required this.items,
    this.showScrollbars = false,
  });

  @override
  State<ReferralReportTable> createState() => _ReferralReportTableState();
}

class _ReferralReportTableState extends State<ReferralReportTable> {
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
                DataColumn(label: Text('Concern')),
                DataColumn(label: Text('Referral Date')),
                DataColumn(label: Text('Follow-Up')),
                DataColumn(label: Text('Status')),
              ],
              rows: widget.items.map((item) {
                return DataRow(
                  cells: [
                    DataCell(Text(item.childId)),
                    DataCell(Text(item.childName)),
                    DataCell(Text(item.concern)),
                    DataCell(Text(item.referralDate)),
                    DataCell(Text(item.followUpDate)),
                    DataCell(Text(item.status)),
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
