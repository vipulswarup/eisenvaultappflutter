import 'package:microsoft_viewer/models/ms_ss_table.dart';

///Class for storing sheet details in xlsx.
class Sheet {
  String name;
  String sheetId;
  String rId;
  List<MsSsTable> tables = [];

  Sheet(this.name, this.sheetId, this.rId);
}
