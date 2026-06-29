import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart' as xml;

/// Extracts readable plain text from Office Open XML files when full rendering fails.
class OfficeDocumentTextExtractor {
  static String? extractText(Uint8List bytes, String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      switch (extension) {
        case 'docx':
          return _extractDocxText(archive);
        case 'xlsx':
          return _extractXlsxText(archive);
        case 'pptx':
          return _extractPptxText(archive);
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  static String? _extractDocxText(Archive archive) {
    ArchiveFile? documentFile;
    for (final file in archive.files) {
      if (file.name == 'word/document.xml') {
        documentFile = file;
        break;
      }
    }
    if (documentFile == null || documentFile.size == 0) return null;

    final document = xml.XmlDocument.parse(utf8.decode(documentFile.content));
    final buffer = StringBuffer();
    for (final textNode in document.findAllElements('w:t')) {
      final text = textNode.innerText;
      if (text.isNotEmpty) {
        if (buffer.isNotEmpty) {
          buffer.write(' ');
        }
        buffer.write(text);
      }
    }
    return buffer.isEmpty ? null : buffer.toString();
  }

  static String? _extractXlsxText(Archive archive) {
    ArchiveFile? sharedStringsFile;
    for (final file in archive.files) {
      if (file.name.endsWith('sharedStrings.xml')) {
        sharedStringsFile = file;
        break;
      }
    }
    if (sharedStringsFile == null || sharedStringsFile.size == 0) return null;

    final document = xml.XmlDocument.parse(utf8.decode(sharedStringsFile.content));
    final buffer = StringBuffer();
    for (final stringItem in document.findAllElements('si')) {
      final text = stringItem.findAllElements('t').map((node) => node.innerText).join();
      if (text.isNotEmpty) {
        if (buffer.isNotEmpty) {
          buffer.writeln();
        }
        buffer.write(text);
      }
    }
    return buffer.isEmpty ? null : buffer.toString();
  }

  static String? _extractPptxText(Archive archive) {
    final buffer = StringBuffer();
    final slideFiles = archive.files
        .where((file) => file.name.startsWith('ppt/slides/slide') && file.name.endsWith('.xml'))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    for (final slideFile in slideFiles) {
      final document = xml.XmlDocument.parse(utf8.decode(slideFile.content));
      for (final textNode in document.findAllElements('a:t')) {
        final text = textNode.innerText;
        if (text.isNotEmpty) {
          if (buffer.isNotEmpty) {
            buffer.writeln();
          }
          buffer.write(text);
        }
      }
    }
    return buffer.isEmpty ? null : buffer.toString();
  }
}
