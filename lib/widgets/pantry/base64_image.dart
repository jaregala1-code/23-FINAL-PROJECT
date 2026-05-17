// lib/widgets/pantry/base64_image.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/image_service.dart';

class Base64Image extends StatefulWidget {
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
  State<Base64Image> createState() => _Base64ImageState();
}

class _Base64ImageState extends State<Base64Image> {
  late Uint8List _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = ImageService.instance.decode(widget.base64);
  }

  @override
  void didUpdateWidget(covariant Base64Image old) {
    super.didUpdateWidget(old);
    if (old.base64 != widget.base64) {
      _bytes = ImageService.instance.decode(widget.base64);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget img = Image.memory(
      _bytes,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
    );
    if (widget.borderRadius != null) {
      img = ClipRRect(borderRadius: widget.borderRadius!, child: img);
    }
    return img;
  }
}
