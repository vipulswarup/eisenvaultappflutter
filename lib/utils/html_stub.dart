// Stub file to allow compilation on non-web platforms
// This file is only used when dart.library.io is available (non-web platforms)

class IFrameElement {
  String src = '';
  final style = _ElementStyle();
}

class _ElementStyle {
  String width = '';
  String height = '';
  String border = '';
}
