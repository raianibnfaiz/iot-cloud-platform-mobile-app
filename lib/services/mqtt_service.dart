import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'api_service.dart';

class MQTTService {
  static final MQTTService _instance = MQTTService._internal();
  MqttServerClient? _client;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final APIService _apiService = APIService();
  static const _maxRetries = 3;
  static const _templateId = 'temp_3725674076';

  // MQTT Broker configuration - using the same URL format as backend
  static const String _brokerUrl = 'mqtt://103.197.206.48';
  static const int _brokerPort = 1883;

  // Stream for widget updates
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  factory MQTTService() {
    return _instance;
  }

  MQTTService._internal();

  // Method to publish module data
  Future<void> publishModuleData(String templateId, String moduleId, Map<String, dynamic> data) async {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      await connect(templateId);
    }

    final topic = templateId;

    _client!.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      MqttClientPayloadBuilder().addString(json.encode(data)).payload!,
    );

    debugPrint('MQTT::Published message to topic: $topic');
    debugPrint('MQTT::Message data: ${json.encode(data)}');
  }

  Future<void> connect(String templateId) async {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      return;
    }
    
    // Generate client ID in the same format as backend
    final clientId = 'client_id_${DateTime.now().millisecondsSinceEpoch}';
    
    // Parse the broker URL to remove mqtt:// prefix
    final brokerAddress = _brokerUrl.replaceAll('mqtt://', '');
    
    _client = MqttServerClient.withPort(brokerAddress, clientId, _brokerPort)
      ..logging(on: true)
      ..keepAlivePeriod = 20
      ..onDisconnected = _onDisconnected
      ..onConnected = _onConnected
      ..onSubscribed = _onSubscribed
      ..pongCallback = _pong
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..setProtocolV311();

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain()
        .withWillTopic(templateId)
        .withWillMessage('offline');

    _client!.connectionMessage = connMessage;

    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        await _client!.connect();
        await Future.delayed(const Duration(seconds: 1));

        if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
          debugPrint('MQTT::Connected to broker successfully');
          _client!.subscribe(templateId, MqttQos.atLeastOnce);
          return;
        } else {
          final status = _client!.connectionStatus!;
          if (retryCount == _maxRetries - 1) {
            throw Exception('Connection failed after $_maxRetries attempts: ${status.returnCode}');
          }
        }
      } catch (e) {
        debugPrint('MQTT::Connection attempt failed: $e');
        if (retryCount == _maxRetries - 1) {
          _client?.disconnect();
          rethrow;
        }
      }

      retryCount++;
      if (retryCount < _maxRetries) {
        final delay = Duration(seconds: 1 << retryCount);
        await Future.delayed(delay);
      }
    }
  }

  void _subscribeToTopics(String templateId) {
    // Subscribe to template-specific topics
    final topics = [
      _templateId,
    ];

    for (final topic in topics) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }

    // Listen for messages
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      if (c == null) return;

      final recMess = c[0].payload as MqttPublishMessage;
      final message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
            
      try {
        // Parse message and send to stream
        final data = {
          'topic': c[0].topic,
          'message': message,
        };
        _messageController.add(data);
      } catch (e) {
      }
    });
  }

  void disconnect() {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      // Publish offline status before disconnecting
      final clientId = _client!.clientIdentifier;
      // _client!.publishMessage(
      //   _templateId,
      //   MqttQos.atLeastOnce,
      //   MqttClientPayloadBuilder().addString('offline').payload!,
      //   retain: true
      // );
    }
    
    debugPrint('MQTT::Disconnecting from broker');
    _client?.disconnect();
  }

  void _onDisconnected() {
    debugPrint('MQTT::Disconnected');
  }

  void _onConnected() {
    debugPrint('MQTT::Connected successfully');
  }

  void _onSubscribed(String topic) {
    debugPrint('MQTT::Subscribed to topic: $topic');
  }

  void _pong() {
    debugPrint('MQTT::Ping response received');
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
} 