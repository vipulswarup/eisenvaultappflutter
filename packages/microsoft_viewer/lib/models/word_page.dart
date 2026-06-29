///Class for storing page details in docx.
class WordPage {
  int pageNumber;
  List<String> componentSequence = [];
  List<dynamic> components = [];
  List<Map<String, String>> footNotes = [];
  List<Map<String, String>> endNotes = [];

  WordPage(this.pageNumber);
}
