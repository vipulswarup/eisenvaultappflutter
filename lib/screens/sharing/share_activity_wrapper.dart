import 'package:flutter/material.dart';
import 'package:eisenvaultappflutter/screens/sharing/android_share_screen.dart';

class ShareActivityWrapper extends StatelessWidget {
  const ShareActivityWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Both iOS and Android use the same screen, but we can pass platform info
    return const AndroidShareScreen();
  }
}
