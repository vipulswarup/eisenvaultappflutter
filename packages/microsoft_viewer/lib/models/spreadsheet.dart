import 'package:microsoft_viewer/models/sheet.dart';

///Class for storing spreadsheet details.
class SpreadSheet {
  String name;
  List<Sheet> sheets = [];

  SpreadSheet(this.name);
}
