import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'models.dart';

/// Builds a PDF with one page image per PDF page, in the given order.
Future<void> assemblePdf({
  required List<String> pagePaths,
  required String pdfPath,
  ScanPageSize pageSize = ScanPageSize.a4,
}) async {
  final format = PdfPageFormat(
    pageSize.widthMm * PdfPageFormat.mm,
    pageSize.heightMm * PdfPageFormat.mm,
    marginAll: 0,
  );
  final doc = pw.Document();
  for (final path in pagePaths) {
    final image = pw.MemoryImage(await File(path).readAsBytes());
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
  }
  await File(pdfPath).writeAsBytes(await doc.save(), flush: true);
}
