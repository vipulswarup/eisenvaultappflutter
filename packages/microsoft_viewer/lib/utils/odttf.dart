import 'package:flutter/foundation.dart';

class ODTTF {
  void deobfuscate(Uint8List fontData, String guid) {
    guid = guid.replaceAll('-', '');

    List<int> key = List<int>.empty(growable: true);
    for (int i = 0; i < 16; i++) {
      String hex = guid.substring(i * 2, (i * 2) + 2);
      int byteValue = int.parse(hex, radix: 16);
      key.add(byteValue);
    }
    // Reverse the key
    key = key.reversed.toList();

    // Apply the XOR operation
    for (int i = 0; i < 32; i++) {
      fontData[i] ^= key[i % key.length];
    }
  }
}
