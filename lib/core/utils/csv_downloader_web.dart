// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

Future<void> downloadCsv({
  required String fileName,
  required String contents,
}) async {
  final blob = html.Blob(<Object>[
    utf8.encode('\uFEFF$contents'),
  ], 'text/csv;charset=utf-8');
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: objectUrl)
    ..download = fileName
    ..click();
  html.Url.revokeObjectUrl(objectUrl);
}
