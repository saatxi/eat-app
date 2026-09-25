import 'package:flutter/material.dart';

/// A stand-in for a screen that is not built yet.
///
/// The bottom navigation is put in place before the four tabs behind it are
/// finished, so tapping into one lands somewhere real rather than nowhere. Each
/// of these is replaced as its own block lands.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Icon(
          Icons.construction,
          size: 64,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
