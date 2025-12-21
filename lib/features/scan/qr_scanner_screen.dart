import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants/app_theme.dart';
import '../../shared/widgets/common_widgets.dart';

class QRScannerScreen extends StatefulWidget {
  final Function(String)? onScanned;
  
  const QRScannerScreen({super.key, this.onScanned});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  
  bool _isScanned = false;
  bool _isFlashOn = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Quét mã QR',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Flash toggle
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: () {
              controller.toggleTorch();
              setState(() => _isFlashOn = !_isFlashOn);
            },
          ),
          // Camera switch
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_isScanned) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null) {
                  _handleScannedCode(code);
                  break;
                }
              }
            },
          ),
          
          // Overlay with scan area
          _buildScanOverlay(),
          
          // Bottom instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Đưa mã QR vào khung hình để quét',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 20),
                // Manual input button
                TextButton.icon(
                  onPressed: () => _showManualInputDialog(),
                  icon: const Icon(Icons.edit, color: Colors.white70),
                  label: const Text(
                    'Nhập địa chỉ thủ công',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return CustomPaint(
      painter: ScanOverlayPainter(),
      child: const SizedBox.expand(),
    );
  }

  void _handleScannedCode(String code) {
    setState(() => _isScanned = true);
    
    // Vibrate feedback
    HapticFeedback.mediumImpact();
    
    // Parse the code
    String address = code;
    String? amount;
    String? chainId;
    
    // Handle ethereum: URI format
    // ethereum:0x...?value=1000000000000000000&chainId=1
    if (code.startsWith('ethereum:')) {
      final uri = Uri.parse(code.replaceFirst('ethereum:', 'http://'));
      address = uri.path;
      amount = uri.queryParameters['value'];
      chainId = uri.queryParameters['chainId'];
    }
    
    // Validate address
    if (!_isValidAddress(address)) {
      _showErrorDialog('Mã QR không chứa địa chỉ ví hợp lệ');
      setState(() => _isScanned = false);
      return;
    }
    
    // Show confirmation
    _showConfirmationDialog(address, amount: amount, chainId: chainId);
  }

  bool _isValidAddress(String address) {
    // Basic Ethereum address validation
    if (!address.startsWith('0x')) return false;
    if (address.length != 42) return false;
    
    // Check if it's valid hex
    try {
      final hex = address.substring(2);
      int.parse(hex, radix: 16);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _showConfirmationDialog(String address, {String? amount, String? chainId}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Địa chỉ đã quét'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Địa chỉ:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Text(
                address,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            if (amount != null) ...[
              const SizedBox(height: 12),
              Text(
                'Số lượng: ${BigInt.parse(amount) / BigInt.from(10).pow(18)} ETH',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isScanned = false);
            },
            child: const Text('Quét lại'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, address); // Return address
              widget.onScanned?.call(address);
            },
            child: const Text('Sử dụng'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lỗi'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showManualInputDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập địa chỉ'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '0x...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final address = controller.text.trim();
              if (_isValidAddress(address)) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, address); // Return address
                widget.onScanned?.call(address);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Địa chỉ không hợp lệ'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }
}

// Custom painter for scan overlay
class ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;
    
    // Scan area size
    final scanAreaSize = size.width * 0.7;
    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2.5;
    final scanRect = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);
    
    // Draw dark overlay with hole
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;
    
    canvas.drawPath(path, paint);
    
    // Draw corner brackets
    final cornerPaint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    const cornerLength = 30.0;
    const cornerRadius = 20.0;
    
    // Top left
    canvas.drawPath(
      Path()
        ..moveTo(left, top + cornerLength)
        ..lineTo(left, top + cornerRadius)
        ..arcToPoint(
          Offset(left + cornerRadius, top),
          radius: const Radius.circular(cornerRadius),
        )
        ..lineTo(left + cornerLength, top),
      cornerPaint,
    );
    
    // Top right
    canvas.drawPath(
      Path()
        ..moveTo(left + scanAreaSize - cornerLength, top)
        ..lineTo(left + scanAreaSize - cornerRadius, top)
        ..arcToPoint(
          Offset(left + scanAreaSize, top + cornerRadius),
          radius: const Radius.circular(cornerRadius),
        )
        ..lineTo(left + scanAreaSize, top + cornerLength),
      cornerPaint,
    );
    
    // Bottom left
    canvas.drawPath(
      Path()
        ..moveTo(left, top + scanAreaSize - cornerLength)
        ..lineTo(left, top + scanAreaSize - cornerRadius)
        ..arcToPoint(
          Offset(left + cornerRadius, top + scanAreaSize),
          radius: const Radius.circular(cornerRadius),
        )
        ..lineTo(left + cornerLength, top + scanAreaSize),
      cornerPaint,
    );
    
    // Bottom right
    canvas.drawPath(
      Path()
        ..moveTo(left + scanAreaSize - cornerLength, top + scanAreaSize)
        ..lineTo(left + scanAreaSize - cornerRadius, top + scanAreaSize)
        ..arcToPoint(
          Offset(left + scanAreaSize, top + scanAreaSize - cornerRadius),
          radius: const Radius.circular(cornerRadius),
        )
        ..lineTo(left + scanAreaSize, top + scanAreaSize - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
