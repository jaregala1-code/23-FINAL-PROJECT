// lib/widgets/pantry/base64_image.dart

import 'package:flutter/material.dart';
import '../../services/image_service.dart';

class Base64Image extends StatelessWidget {
  const Base64Image({
    super.key,
    required this.base64,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String base64;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final bytes = ImageService.instance.decode(base64);
    Widget img = Image.memory(bytes, width: width, height: height, fit: fit);
    if (borderRadius != null) {
      img = ClipRRect(borderRadius: borderRadius!, child: img);
    }
    return img;
  }
}
