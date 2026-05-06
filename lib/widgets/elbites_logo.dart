import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ElbitesLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const ElbitesLogo({super.key, this.size = 56, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: AppColors.green.withOpacity(0.35),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [Text('🌿', style: TextStyle(fontSize: size * 0.45))],
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'EL',
                  style: TextStyle(
                    color: AppColors.yellow,
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                    fontFamily: 'Sora',
                  ),
                ),
                TextSpan(
                  text: 'Bites',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.5,
                    fontFamily: 'Sora',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
