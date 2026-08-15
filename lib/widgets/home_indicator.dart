import 'package:flutter/widgets.dart';

/// The thin bar at the bottom of both reference screens.
class HomeIndicator extends StatelessWidget {
  const HomeIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFF4A4A4A),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
