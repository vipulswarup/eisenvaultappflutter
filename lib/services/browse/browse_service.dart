import 'package:eisenvaultappflutter/models/browse_item.dart';

abstract class BrowseService {
  Future<List<BrowseItem>> getChildren(BrowseItem parent);
}
