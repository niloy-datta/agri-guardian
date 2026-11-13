import 'package:flutter/material.dart';

/// Circular progress score indicator (e.g. 92% AI শনাক্তকরণ)
class CircularScoreIndicator extends StatelessWidget {
  final double scorePercent;
  final double size;
  final Color progressColor;
  final Color backgroundColor;
  final TextStyle? textStyle;

  const CircularScoreIndicator({
    super.key,
    required this.scorePercent,
    this.size = 64,
    this.progressColor = const Color(0xFF087A43),
    this.backgroundColor = const Color(0xFFE2E8F0),
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: scorePercent / 100.0,
            strokeWidth: size * 0.1,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            strokeCap: StrokeCap.round,
          ),
          Text(
            '${scorePercent.toInt()}%',
            style: textStyle ??
                TextStyle(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w800,
                  color: progressColor,
                ),
          ),
        ],
      ),
    );
  }
}
