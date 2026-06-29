///Classes for storing details of SpreadSheet tables.
class MsSsTable {
  ///List of columns
  List<MsSsCol> cols = [];

  ///List of rows
  List<MsSsRow> rows = [];
}
///Class for columns
class MsSsCol {
  ///Minimum
  int min;
  ///Maximum
  int max;
  ///Width
  double width;
  ///Custom width
  int customWidth;
  ///Constructor
  MsSsCol(this.min, this.max, this.width, this.customWidth);
}
///Class for row
class MsSsRow {
  ///id
  int rowId;
  ///Span
  String spans;
  ///Height
  double height;
  ///Row style
  String? style;
  ///List of cells
  List<MsSsCell> cells = [];
  ///Constructor
  MsSsRow(this.rowId, this.spans, this.height);
}

///Class for cells
class MsSsCell {
  ///No
  int colNo;
  ///type
  String type;
  ///Value
  String value;
  ///Style
  String? style;
  ///Col spans
  int colSpan;
  ///Constructor
  MsSsCell(this.colNo, this.type, this.value, this.colSpan);
}
