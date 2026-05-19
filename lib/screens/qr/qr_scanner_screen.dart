// lib/screens/qr/qr_scanner_screen.dart
//
// Giver-side QR scanner. Verifies the QR a Receiver presents at pickup and
// commits the exchange via [ClaimService.completeExchange].
//

import 'dart:async';
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

enum _ScanPhase {
  initializing,
  scanning,
  processing,
  success,
  failure,
  permissionDenied,
  cameraError,
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _ctrl;

  _ScanPhase _phase = _ScanPhase.initializing;
  String _message = '';
  bool _processingGuard = false; // sync guard for duplicate detections

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootScanner();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (_phase == _ScanPhase.scanning) {
          ctrl.start().catchError((_) {});
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        ctrl.stop().catchError((_) {});
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  Future<void> _disposeController() async {
    final ctrl = _ctrl;
    _ctrl = null;
    if (ctrl == null) return;
    try {
      await ctrl.dispose();
    } catch (_) {
      // Safe to ignore — happens if the platform side already tore down.
    }
  }

  Future<void> _bootScanner() async {
    await _disposeController();
    _processingGuard = false;
    if (!mounted) return;
    setState(() {
      _phase = _ScanPhase.initializing;
      _message = '';
    });

    final ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      detectionTimeoutMs: 1000,
      formats: const [BarcodeFormat.qrCode],
    );
    _ctrl = ctrl;

    try {
      await ctrl.start();
      if (!mounted) return;
      setState(() => _phase = _ScanPhase.scanning);
    } on MobileScannerException catch (e) {
      if (!mounted) return;
      final code = e.errorCode;
      if (code == MobileScannerErrorCode.permissionDenied) {
        setState(() {
          _phase = _ScanPhase.permissionDenied;
          _message = 'Camera permission is required to scan QR codes.';
        });
      } else {
        setState(() {
          _phase = _ScanPhase.cameraError;
          _message =
              'The camera is unavailable. ${e.errorDetails?.message ?? ''}'
                  .trim();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _ScanPhase.cameraError;
        _message = 'The camera could not be started.';
      });
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processingGuard) return;
    if (_phase != _ScanPhase.scanning) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    _processingGuard = true; // sync flip BEFORE awaits
    setState(() => _phase = _ScanPhase.processing);

    await _ctrl?.stop().catchError((_) {});

    try {
      final Map<String, dynamic> decoded;
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        _setFailure('That QR code is not in the right format.');
        return;
      }

      final scannedItemId = decoded['itemId'] as String?;
      final claimerId = decoded['claimerId'] as String?;
      final reqId = decoded['reqId'] as String?;

      if (scannedItemId == null || claimerId == null || reqId == null) {
        _setFailure('That QR code is missing required fields.');
        return;
      }

      if (scannedItemId != widget.item.id) {
        _setFailure('QR code does not match this item.\nDo not hand it over.');
        return;
      }

      final ownerUid = FirebaseAuth.instance.currentUser?.uid;
      if (ownerUid == null) {
        _setFailure('You must be signed in to confirm the exchange.');
        return;
      }
      if (ownerUid != widget.item.ownerUid) {
        _setFailure('Only the item owner can confirm this exchange.');
        return;
      }

      final ok = await ClaimService.instance.completeExchange(
        itemId: scannedItemId,
        itemTitle: widget.item.title,
        reqId: reqId,
        claimerId: claimerId,
        ownerUid: ownerUid,
      );

      if (!mounted) return;
      if (ok) {
        setState(() {
          _phase = _ScanPhase.success;
          _message = '✅ Exchange confirmed!\nYou can hand over the item.';
        });
      } else {
        _setFailure(
          'Could not confirm exchange. This code may already be used.',
        );
      }
    } catch (e) {
      _setFailure('Something went wrong while verifying. Please try again.');
    }
  }

  void _setFailure(String msg) {
    if (!mounted) return;
    setState(() {
      _phase = _ScanPhase.failure;
      _message = msg;
    });
  }

  Future<void> _toggleTorch() async {
    try {
      await _ctrl?.toggleTorch();
    } catch (_) {
      // Some devices lack a torch — silently ignore.
    }
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
          if (_phase == _ScanPhase.scanning)
            IconButton(
              icon: const Icon(Icons.flash_on_rounded, color: AppColors.white),
              onPressed: _toggleTorch,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _ScanPhase.initializing:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.yellow),
        );
      case _ScanPhase.permissionDenied:
        return _ErrorPanel(
          icon: Icons.no_photography_outlined,
          title: 'Camera permission needed',
          message: _message,
          primaryLabel: 'Try Again',
          onPrimary: _bootScanner,
        );
      case _ScanPhase.cameraError:
        return _ErrorPanel(
          icon: Icons.videocam_off_outlined,
          title: 'Camera unavailable',
          message: _message,
          primaryLabel: 'Retry',
          onPrimary: _bootScanner,
        );
      case _ScanPhase.success:
      case _ScanPhase.failure:
        return _ResultPanel(
          success: _phase == _ScanPhase.success,
          message: _message,
          onRetry: _phase == _ScanPhase.failure ? _bootScanner : null,
          onClose: () => Navigator.pop(context),
        );
      case _ScanPhase.scanning:
      case _ScanPhase.processing:
        return _buildScanner();
    }
  }

  Widget _buildScanner() {
    final ctrl = _ctrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (ctrl != null)
          MobileScanner(controller: ctrl, onDetect: _onDetect)
        else
          const ColoredBox(color: Colors.black),

        _ScanOverlay(),

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

        if (_phase == _ScanPhase.processing)
          const Center(
            child: CircularProgressIndicator(color: AppColors.yellow),
          ),

        if (_phase == _ScanPhase.scanning)
          const Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Point camera at the Receiver's QR code",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Result + error panels ─────────────────────────────────────────────────────

class _ResultPanel extends StatelessWidget {
  final bool success;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onClose;

  const _ResultPanel({
    required this.success,
    required this.message,
    required this.onClose,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
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
                color: (success ? AppColors.green : AppColors.error).withValues(
                  alpha: 0.15,
                ),
              ),
              child: Icon(
                success
                    ? Icons.check_circle_outline_rounded
                    : Icons.cancel_outlined,
                size: 60,
                color: success ? AppColors.green : AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              success ? 'Exchange Complete!' : 'Verification Failed',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Try Again'),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onClose,
              child: Text(success ? 'Done' : 'Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;

  const _ErrorPanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.mutedText),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(onPressed: onPrimary, child: Text(primaryLabel)),
          ],
        ),
      ),
    );
  }
}

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

    final cornerPaint = Paint()
      ..color = AppColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const l = 24.0;
    canvas.drawLine(Offset(left, top + l), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + l, top), cornerPaint);
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
