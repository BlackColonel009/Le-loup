import 'package:flutter/material.dart';

/// Preserve intentional spacers while keeping actions apart from their neighbours.
List<Widget> spaceGameActions(List<Widget> children, {double gap = 12}) {
  final result = <Widget>[];
  Widget? previous;
  for (final child in children) {
    final hasAction =
        child is ButtonStyleButton || previous is ButtonStyleButton;
    final alreadySpaced =
        child is SizedBox ||
        previous is SizedBox ||
        child is Divider ||
        previous is Divider;
    if (previous != null && hasAction && !alreadySpaced) {
      result.add(SizedBox(height: gap));
    }
    result.add(child);
    previous = child;
  }
  return result;
}
