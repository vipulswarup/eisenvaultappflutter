import 'package:microsoft_viewer/models/slide.dart';

///Class for storing presentation details.
class Presentation {
  String name;
  List<Slide> slides = [];
  List<Slide> masterSlides = [];
  int? width;
  int? height;

  Presentation(this.name);
}
