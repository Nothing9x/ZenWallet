import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Check if device supports biometrics
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Check if biometrics are enrolled
  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Check if biometric authentication is available
  Future<BiometricStatus> checkBiometricStatus() async {
    final isSupported = await isDeviceSupported();
    if (!isSupported) {
      return BiometricStatus.notSupported;
    }

    final canCheck = await canCheckBiometrics();
    if (!canCheck) {
      return BiometricStatus.notEnrolled;
    }

    final availableBiometrics = await getAvailableBiometrics();
    if (availableBiometrics.isEmpty) {
      return BiometricStatus.notEnrolled;
    }

    return BiometricStatus.available;
  }

  /// Get biometric type name for UI
  Future<String> getBiometricTypeName() async {
    final biometrics = await getAvailableBiometrics();
    
    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Vân tay';
    } else if (biometrics.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (biometrics.contains(BiometricType.strong)) {
      return 'Sinh trắc học';
    } else if (biometrics.contains(BiometricType.weak)) {
      return 'Sinh trắc học';
    }
    
    return 'Sinh trắc học';
  }

  /// Authenticate with biometrics
  Future<BiometricResult> authenticate({
    String reason = 'Xác thực để truy cập ví',
    bool biometricOnly = false,
  }) async {
    try {
      final status = await checkBiometricStatus();
      if (status != BiometricStatus.available) {
        return BiometricResult(
          success: false,
          error: _getStatusErrorMessage(status),
        );
      }

      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      return BiometricResult(success: authenticated);
    } on PlatformException catch (e) {
      return BiometricResult(
        success: false,
        error: _getErrorMessage(e),
        errorCode: e.code,
      );
    }
  }

  /// Authenticate for sensitive operations (e.g., viewing seed phrase)
  Future<BiometricResult> authenticateForSensitiveAction({
    required String reason,
  }) async {
    return authenticate(
      reason: reason,
      biometricOnly: true,
    );
  }

  /// Cancel ongoing authentication
  Future<void> cancelAuthentication() async {
    await _auth.stopAuthentication();
  }

  String _getStatusErrorMessage(BiometricStatus status) {
    switch (status) {
      case BiometricStatus.notSupported:
        return 'Thiết bị không hỗ trợ xác thực sinh trắc học';
      case BiometricStatus.notEnrolled:
        return 'Chưa thiết lập sinh trắc học trên thiết bị';
      case BiometricStatus.available:
        return '';
    }
  }

  String _getErrorMessage(PlatformException e) {
    switch (e.code) {
      case auth_error.notAvailable:
        return 'Sinh trắc học không khả dụng';
      case auth_error.notEnrolled:
        return 'Chưa thiết lập sinh trắc học';
      case auth_error.lockedOut:
        return 'Đã khóa do quá nhiều lần thử. Vui lòng thử lại sau.';
      case auth_error.permanentlyLockedOut:
        return 'Đã bị khóa vĩnh viễn. Vui lòng sử dụng mật khẩu thiết bị.';
      case auth_error.passcodeNotSet:
        return 'Chưa thiết lập mật khẩu thiết bị';
      case auth_error.otherOperatingSystem:
        return 'Không hỗ trợ trên hệ điều hành này';
      default:
        return e.message ?? 'Lỗi xác thực không xác định';
    }
  }
}

enum BiometricStatus {
  available,
  notSupported,
  notEnrolled,
}

class BiometricResult {
  final bool success;
  final String? error;
  final String? errorCode;

  BiometricResult({
    required this.success,
    this.error,
    this.errorCode,
  });

  bool get isLocked => errorCode == auth_error.lockedOut || 
                        errorCode == auth_error.permanentlyLockedOut;
}
