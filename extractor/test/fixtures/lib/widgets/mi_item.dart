import 'package:flutter/material.dart';

class MiItem extends StatelessWidget {
  final String label;
  const MiItem({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label);
  }
}
