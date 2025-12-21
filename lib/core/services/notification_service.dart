import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/network.dart';

/// Service to monitor blockchain transactions and send notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final Map<String, WebSocketChannel> _wsChannels = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  
  // Callbacks
  Function(TransactionNotification)? onTransactionReceived;
  Function(TransactionNotification)? onTransactionConfirmed;

  // WebSocket URLs for different networks (using public endpoints)
  static const Map<String, String> _wsUrls = {
    'ethereum': 'wss://ethereum.publicnode.com',
    'bsc': 'wss://bsc.publicnode.com',
    'polygon': 'wss://polygon-bor.publicnode.com',
    'arbitrum': 'wss://arbitrum-one.publicnode.com',
    'optimism': 'wss://optimism.publicnode.com',
    'avalanche': 'wss://avalanche-c-chain.publicnode.com',
  };

  /// Initialize notification service
  Future<void> initialize() async {
    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();
  }

  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'transaction_channel',
      'Giao dịch',
      description: 'Thông báo về giao dịch ví',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    final payload = response.payload;
    if (payload != null) {
      try {
        final data = json.decode(payload);
        debugPrint('Notification tapped: $data');
        // Navigate to transaction details
      } catch (_) {}
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    // Android 13+
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    // iOS
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// Start monitoring an address for incoming transactions
  Future<void> startMonitoring({
    required String address,
    required Network network,
  }) async {
    final wsUrl = _wsUrls[network.id];
    if (wsUrl == null) {
      debugPrint('WebSocket not available for ${network.id}');
      return;
    }

    final key = '${network.id}_$address';
    
    // Don't create duplicate connections
    if (_wsChannels.containsKey(key)) {
      return;
    }

    try {
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsChannels[key] = channel;

      // Subscribe to pending transactions for the address
      final subscribeMsg = json.encode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'eth_subscribe',
        'params': [
          'alchemy_pendingTransactions',
          {
            'toAddress': address,
            'hashesOnly': false,
          }
        ]
      });

      channel.sink.add(subscribeMsg);

      // Listen for messages
      _subscriptions[key] = channel.stream.listen(
        (message) => _handleWebSocketMessage(message, address, network),
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _reconnect(address, network);
        },
        onDone: () {
          debugPrint('WebSocket closed for $key');
          _wsChannels.remove(key);
          _subscriptions.remove(key);
        },
      );

      debugPrint('Started monitoring $address on ${network.name}');
    } catch (e) {
      debugPrint('Failed to connect WebSocket: $e');
    }
  }

  /// Stop monitoring an address
  void stopMonitoring({
    required String address,
    required Network network,
  }) {
    final key = '${network.id}_$address';
    
    _subscriptions[key]?.cancel();
    _wsChannels[key]?.sink.close();
    
    _subscriptions.remove(key);
    _wsChannels.remove(key);
    
    debugPrint('Stopped monitoring $address on ${network.name}');
  }

  /// Stop all monitoring
  void stopAllMonitoring() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    for (final channel in _wsChannels.values) {
      channel.sink.close();
    }
    _subscriptions.clear();
    _wsChannels.clear();
  }

  void _handleWebSocketMessage(dynamic message, String address, Network network) {
    try {
      final data = json.decode(message);
      
      if (data['method'] == 'eth_subscription') {
        final params = data['params'];
        final result = params['result'];
        
        if (result != null) {
          final tx = TransactionNotification(
            hash: result['hash'] ?? '',
            from: result['from'] ?? '',
            to: result['to'] ?? '',
            value: BigInt.tryParse(result['value'] ?? '0') ?? BigInt.zero,
            network: network,
            isPending: true,
          );

          // Check if it's incoming transaction
          if (tx.to.toLowerCase() == address.toLowerCase()) {
            _showTransactionNotification(tx);
            onTransactionReceived?.call(tx);
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }

  Future<void> _reconnect(String address, Network network) async {
    final key = '${network.id}_$address';
    
    // Clean up old connection
    _subscriptions[key]?.cancel();
    _wsChannels[key]?.sink.close();
    _subscriptions.remove(key);
    _wsChannels.remove(key);

    // Wait before reconnecting
    await Future.delayed(const Duration(seconds: 5));

    // Reconnect
    await startMonitoring(address: address, network: network);
  }

  /// Show local notification for a transaction
  Future<void> _showTransactionNotification(TransactionNotification tx) async {
    final formattedValue = (tx.value / BigInt.from(10).pow(18)).toStringAsFixed(4);
    
    await _notifications.show(
      tx.hash.hashCode,
      tx.isPending ? '💰 Giao dịch đang đến' : '✅ Giao dịch thành công',
      'Nhận $formattedValue ${tx.network.symbol} từ ${_shortenAddress(tx.from)}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'transaction_channel',
          'Giao dịch',
          channelDescription: 'Thông báo về giao dịch ví',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(
            'Nhận $formattedValue ${tx.network.symbol}\n'
            'Từ: ${tx.from}\n'
            'Mạng: ${tx.network.name}',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: json.encode({
        'hash': tx.hash,
        'network': tx.network.id,
      }),
    );
  }

  /// Show custom notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'transaction_channel',
          'Giao dịch',
          channelDescription: 'Thông báo về giao dịch ví',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  /// Show transaction confirmed notification
  Future<void> showTransactionConfirmed({
    required String hash,
    required String amount,
    required String symbol,
    required bool isReceived,
  }) async {
    await showNotification(
      title: isReceived ? '✅ Đã nhận $amount $symbol' : '✅ Đã gửi $amount $symbol',
      body: 'Giao dịch đã được xác nhận trên blockchain',
      payload: json.encode({'hash': hash}),
    );
  }

  /// Show transaction failed notification
  Future<void> showTransactionFailed({
    required String hash,
    String? reason,
  }) async {
    await showNotification(
      title: '❌ Giao dịch thất bại',
      body: reason ?? 'Giao dịch không thành công. Vui lòng thử lại.',
      payload: json.encode({'hash': hash}),
    );
  }

  String _shortenAddress(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  /// Dispose service
  void dispose() {
    stopAllMonitoring();
  }
}

class TransactionNotification {
  final String hash;
  final String from;
  final String to;
  final BigInt value;
  final Network network;
  final bool isPending;

  TransactionNotification({
    required this.hash,
    required this.from,
    required this.to,
    required this.value,
    required this.network,
    this.isPending = true,
  });
}
