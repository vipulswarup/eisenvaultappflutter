import 'dart:ui';

///Class for storing shapes in presentations.
class PresentationShape {
  ///Id of the shape
  String id;

  ///Text in the shape
  String text;

  ///Offset of the shape
  Offset offset;

  ///Size of the shape
  Size size;

  ///Constructor
  PresentationShape(this.id, this.text, this.offset, this.size);
}
