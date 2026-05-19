// lib/screens/qr/qr_scanner_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/surplus_item.dart';
import '../../services/claim_service.dart';
import '../../theme/app_theme.dart';

class QRScannerScreen extends StatefulWidget {
  final SurplusItem item;
  const QRScannerScreen({super.key, required this.item});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController? _ctrl;
  bool _processing = false;
  bool _done = false;
  bool _success = false;
  String _resultMsg = '';

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _done) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() => _processing = true);
    await _ctrl?.stop();

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final scannedItemId = decoded['itemId'] as String?;
      final claimerId = decoded['claimerId'] as String?;
      final reqId = decoded['reqId'] as String?;

      if (scannedItemId != widget.item.id) {
        _setResult(
          false,
          'QR code does not match this item.\nDo not hand it over.',
        );
        return;
      }
      if (claimerId == null || reqId == null) {
        _setResult(false, 'Invalid QR code format.');
        return;
      }

      final ownerUid = FirebaseAuth.instance.currentUser?.uid;
      if (ownerUid == null) {
        _setResult(false, 'You must be signed in to confirm the exchange.');
        return;
      }

      final ok = await ClaimService.instance.completeExchange(
        itemId: scannedItemId!,
        reqId: reqId,
        claimerId: claimerId,
      );

      if (ok) {
        _setResult(true, '✅ Exchange confirmed!\nYou can hand over the item.');
      } else {
        _setResult(
          false,
          'Could not confirm exchange. This code may already be used.',
        );
      }
    } catch (e) {
      _setResult(false, 'Could not read QR code. Please try again.');
    }
  }

  void _setResult(bool success, String msg) {
    setState(() {
      _processing = false;
      _done = true;
      _success = success;
      _resultMsg = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan Receiver QR',
          style: TextStyle(color: AppColors.white),
        ),
        actions: [
          if (!_done)
            IconButton(
              icon: const Icon(Icons.flash_on_rounded, color: AppColors.white),
              onPressed: () => _ctrl?.toggleTorch(),
            ),
        ],
      ),
      body: _done ? _buildResult() : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: _ctrl!, onDetect: _onDetect),

        // Semi-transparent overlay with cutout
        _ScanOverlay(),

        // Item label
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Verifying: ${widget.item.title}',
                style: const TextStyle(color: AppColors.white, fontSize: 14),
              ),
            ),
          ),
        ),

        // Processing indicator
        if (_processing)
          const Center(
            child: CircularProgressIndicator(color: AppColors.yellow),
          ),

        // Bottom hint
        if (!_processing)
          const Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Point camera at the Receiver\'s QR code',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (_success ? AppColors.green : AppColors.error)
                    .withValues(alpha: 0.15),
              ),
              child: Icon(
                _success
                    ? Icons.check_circle_outline_rounded
                    : Icons.cancel_outlined,
                size: 60,
                color: _success ? AppColors.green : AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _success ? 'Exchange Complete!' : 'Verification Failed',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _resultMsg,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (!_success)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _done = false;
                    _processing = false;
                    _success = false;
                  });
                  _ctrl?.start();
                },
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Try Again'),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_success ? 'Done' : 'Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scan overlay cutout ────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _OverlayPainter(), child: Container());
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final cutW = size.width * 0.7;
    final cutH = cutW;
    final left = (size.width - cutW) / 2;
    final top = (size.height - cutH) / 2;
    final rect = Rect.fromLTWH(left, top, cutW, cutH);

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // Corner marks
    final cornerPaint = Paint()
      ..color = AppColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const l = 24.0;
    // Top-left
    canvas.drawLine(Offset(left, top + l), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + l, top), cornerPaint);
    // Top-right
    canvas.drawLine(
      Offset(left + cutW - l, top),
      Offset(left + cutW, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + cutW, top),
      Offset(left + cutW, top + l),
      cornerPaint,
    );
    // Bottom-left
    canvas.drawLine(
      Offset(left, top + cutH - l),
      Offset(left, top + cutH),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, top + cutH),
      Offset(left + l, top + cutH),
      cornerPaint,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(left + cutW, top + cutH - l),
      Offset(left + cutW, top + cutH),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + cutW - l, top + cutH),
      Offset(left + cutW, top + cutH),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
