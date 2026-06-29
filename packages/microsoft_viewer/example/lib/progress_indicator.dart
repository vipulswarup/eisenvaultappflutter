import 'package:flutter/material.dart';

class ProgressIndicatorView extends StatefulWidget {
  const ProgressIndicatorView({super.key});

  @override
  State<StatefulWidget> createState() => ProgressIndicatorState();
}

class ProgressIndicatorState extends State<ProgressIndicatorView> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
