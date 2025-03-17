import 'package:eisenvaultappflutter/models/browse_item.dart';

abstract class BrowseService {
  // Add pagination parameters
  Future<List<BrowseItem>> getChildren(
    BrowseItem parent, {
    int skipCount = 0,
    int maxItems = 25,
  });
}
