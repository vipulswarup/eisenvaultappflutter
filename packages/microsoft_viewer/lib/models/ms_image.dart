///Class for storing image details
class MsImage {
  ///Image sequence number
  int pSeqNo;

  ///Image path
  String imagePath;

  ///Image type
  String type;

  ///Image width
  int cx;

  ///Image height
  int cy;
  ///Constructor
  MsImage(this.pSeqNo, this.imagePath, this.type, this.cx, this.cy);
}
