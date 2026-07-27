import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme.dart';
import '../../gen_l10n/app_localizations.dart';
import '../profiles/profiles_provider.dart';

/// QR 码扫描导入页面
class QrScanPage extends ConsumerStatefulWidget {
  const QrScanPage({super.key});

  @override
  ConsumerState<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends ConsumerState<QrScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;
  String? _resultMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final value = barcode.rawValue!;
    _processScannedValue(value);
  }

  Future<void> _processScannedValue(String value) async {
    setState(() {
      _isProcessing = true;
      _resultMessage = null;
    });

    try {
      final count = await ref.read(profilesProvider.notifier).importBatch(value);
      if (count == 0) {
        setState(() {
          _resultMessage = AppLocalizations.of(context).qrNoNodeDetected;
          _isSuccess = false;
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _resultMessage = count == 1
            ? AppLocalizations.of(context).qrImportSuccess(value.length > 30 ? '${value.substring(0, 30)}...' : value)
            : AppLocalizations.of(context).qrImportMultiple(count);
        _isSuccess = true;
        _isProcessing = false;
      });

      // 成功后短暂延迟后返回
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _resultMessage = '${AppLocalizations.of(context).qrImportFailed}: $e';
        _isSuccess = false;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l.qrScanTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),
          // 扫描框 overlay
          _buildScanOverlay(),
          // 结果提示
          if (_resultMessage != null) _buildResultBanner(l),
          // 底部提示
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _isProcessing ? l.qrProcessing : l.qrScanHint,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return CustomPaint(
      painter: _ScanOverlayPainter(),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildResultBanner(AppLocalizations l) {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _isSuccess ? FlowGateTheme.success : FlowGateTheme.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              _isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _resultMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 扫描框遮罩画笔
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final scanSize = size.width * 0.7;
    final left = (size.width - scanSize) / 2;
    final top = (size.height - scanSize) / 2.5;
    final scanRect = Rect.fromLTWH(left, top, scanSize, scanSize);

    // 半透明背景（排除扫描区域）
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, bgPaint);

    // 扫描框边框
    final borderPaint = Paint()
      ..color = FlowGateTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(16)),
      borderPaint,
    );

    // 四角装饰
    final cornerPaint = Paint()
      ..color = FlowGateTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const cornerLen = 24.0;

    // 左上
    canvas.drawLine(Offset(left, top + 16), Offset(left, top + 16 + cornerLen), cornerPaint);
    canvas.drawLine(Offset(left + 16, top), Offset(left + 16 + cornerLen, top), cornerPaint);
    // 右上
    canvas.drawLine(Offset(left + scanSize, top + 16), Offset(left + scanSize, top + 16 + cornerLen), cornerPaint);
    canvas.drawLine(Offset(left + scanSize - 16, top), Offset(left + scanSize - 16 - cornerLen, top), cornerPaint);
    // 左下
    canvas.drawLine(Offset(left, top + scanSize - 16), Offset(left, top + scanSize - 16 - cornerLen), cornerPaint);
    canvas.drawLine(Offset(left + 16, top + scanSize), Offset(left + 16 + cornerLen, top + scanSize), cornerPaint);
    // 右下
    canvas.drawLine(Offset(left + scanSize, top + scanSize - 16), Offset(left + scanSize, top + scanSize - 16 - cornerLen), cornerPaint);
    canvas.drawLine(Offset(left + scanSize - 16, top + scanSize), Offset(left + scanSize - 16 - cornerLen, top + scanSize), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
