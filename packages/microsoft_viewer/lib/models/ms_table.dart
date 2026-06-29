///Classes for storing tables in word documents.
class MsTable {
  ///Table sequence number
  int seqNo;
  List<MsTableRow> rows = [];
  int colNums = 0;
  String tblStyle;
  String rightFromText;
  String bottomFromText;
  String vertAnchor;
  String tblpY;
  String tblWidth;
  String tblWType;
  String tblLook;

  MsTable(
      this.seqNo, this.tblStyle, this.rightFromText, this.bottomFromText, this.vertAnchor, this.tblpY, this.tblWidth, this.tblWType, this.tblLook);
}

class MsTableRow {
  bool isFirstRow;
  bool isLastRow;
  bool isFirstCol;
  bool isLastCol;
  int? gridSpan;
  List<MsTableCell> cells = [];

  MsTableRow(this.isFirstRow, this.isLastRow, this.isFirstCol, this.isLastCol);
}

class MsTableCell {
  String cellText;
  int cellWidth;

  MsTableCell(this.cellText, this.cellWidth);
}
