import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';

class MqttService {

  late MqttServerClient client;

  final String broker = '192.168.1.4';  // SEU IP AQUI
  final int port = 1883;
  final String clientId = 'flutter_caldeira';

  Timer? _timerTemperatura;
  Timer? _timerUmidade;
  StreamSubscription? _gyroscopeSubscription;

  Function(String topic, String message)? onMessageReceived;
  Function(bool connected)? onConnectionChanged;
  
  // Callbacks para atualizar valores na tela
  Function(double temperatura)? onTemperaturaAtualizada;
  Function(double umidade)? onUmidadeAtualizada;
  Function(String alerta)? onAlertaRecebido;
  Function(Map<String, dynamic> notificacao)? onNotificacaoRecebida;

  // Variáveis para controlar movimento do giroscópio
  double _ultimaLeituraGiroscopio = 0.0;
  double _ultimaTemperatura = 25.0;  // Temperatura inicial padrão
  bool _houveMovimento = false;
  
  // Limiar para detectar movimento (ajuste se necessário)
  final double _limiarMovimento = 0.5;

  // Método para conectar
  Future<bool> connect() async {
    client = MqttServerClient(broker, clientId);
    client.port = port;
    client.keepAlivePeriod = 20;
    client.logging(on: true);
    client.autoReconnect = false;
    client.connectTimeoutPeriod = 5000;

    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;

    final connMessage = MqttConnectMessage()
      .withClientIdentifier(clientId)
      .startClean()
      .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMessage;

    try {
      print('🔌 Tentando conectar ao broker $broker:$port...');
      await client.connect();

      await Future.delayed(const Duration(seconds: 2));

      print('📊 Status: ${client.connectionStatus?.state}');
      
      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        print('✅ Conectado com sucesso!');
        return true;
      } else {
        print('❌ Falha na conexão');
        print('Estado: ${client.connectionStatus!.state}');
        print('Código: ${client.connectionStatus!.returnCode}');
        return false;
      }
    } catch (e) {
      print('❌ Erro ao conectar: $e');
      print('Tipo: ${e.runtimeType}');
      client.disconnect();
      return false;
    }
  }

  void onConnected() {
    print('✅ Callback: Conectado ao broker');
    
    // Inscreve-se no tópico de alertas
    _inscreverAlertas();
    
    onConnectionChanged?.call(true);
  }
  
  void _inscreverAlertas() {
    const topico = 'caldeira/alertas';
    client.subscribe(topico, MqttQos.atLeastOnce);
    print('🔔 Inscrito no tópico de alertas: $topico');
    
    // Configura listener para alertas
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final message = messages[0];
      final topic = message.topic;
      final payload = MqttPublishPayload.bytesToStringAsString(
        (message.payload as MqttPublishMessage).payload.message
      );
      
      if (topic == topico) {
        print('🚨 Alerta recebido: $payload');
        onAlertaRecebido?.call(payload);
      }
    });
  }

  void onDisconnected() {
    print('❌ Callback: Desconectado do broker');
    pararSensores();
    onConnectionChanged?.call(false);
  }

  void publish(String topic, String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    print('📤 Publicado: $topic -> $message');
  }

  void disconnect() {
    pararSensores();
    client.disconnect();
    print('👋 Desconectando do broker...');
  }

  // Iniciar monitoramento do giroscópio
  void _iniciarMonitoramentoGiroscopio() {
    _gyroscopeSubscription?.cancel();
    _houveMovimento = false;
    
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      // Calcula a magnitude do movimento (rotação)
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      
      // Verifica se houve movimento significativo
      if ((magnitude - _ultimaLeituraGiroscopio).abs() > _limiarMovimento) {
        _houveMovimento = true;
        print('🔄 Movimento detectado! Magnitude: ${magnitude.toStringAsFixed(2)}');
      }
      
      _ultimaLeituraGiroscopio = magnitude;
    });
    
    print('📱 Monitoramento de giroscópio iniciado');
  }

  // Parar monitoramento do giroscópio
  void _pararMonitoramentoGiroscopio() {
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    print('📱 Monitoramento de giroscópio parado');
  }

  void iniciarSensorTemperatura() {
    _timerTemperatura?.cancel();
    
    // Inicia monitoramento do giroscópio
    _iniciarMonitoramentoGiroscopio();
    
    // Envia primeira leitura imediatamente
    _enviarTemperatura();
    
    // Configura timer para enviar a cada 60 segundos
    _timerTemperatura = Timer.periodic(const Duration(seconds: 60), (timer) {
      _enviarTemperatura();
    });

    print('🌡️ Sensor de temperatura iniciado (envia a cada 60s)');
  }
  
  void _enviarTemperatura() {
    double novaTemperatura;
    
    if (_houveMovimento) {
      // Houve movimento: gera nova temperatura aleatória entre 20°C e 100°C
      final random = Random();
      novaTemperatura = 0 + (random.nextDouble() * 300);
      _ultimaTemperatura = novaTemperatura;
      _houveMovimento = false;  // Reseta flag
      print('🔥 Movimento detectado! Nova temperatura: ${novaTemperatura.toStringAsFixed(1)}°C');
    } else {
      // Sem movimento: mantém última temperatura
      novaTemperatura = _ultimaTemperatura;
      print('❄️ Sem movimento. Mantendo temperatura: ${novaTemperatura.toStringAsFixed(1)}°C');
    }
    
    publish('caldeira/temperatura', novaTemperatura.toStringAsFixed(1));
    onTemperaturaAtualizada?.call(novaTemperatura);
  }

  void iniciarSensorUmidade() {
    _timerUmidade?.cancel();

    // Envia primeira leitura imediatamente
    _enviarUmidade();
    
    // Configura timer para enviar a cada 60 segundos
    _timerUmidade = Timer.periodic(const Duration(seconds: 60), (timer) {
      _enviarUmidade();
    });

    print('💧 Sensor de umidade iniciado (envia a cada 60s)');
  }
  
  void _enviarUmidade() {
    // Umidade continua aleatória (ou você pode adicionar outra lógica)
    final umidade = 30 + (60 * (DateTime.now().millisecondsSinceEpoch % 100) / 100);
    publish('caldeira/umidade', umidade.toStringAsFixed(1));
    
    onUmidadeAtualizada?.call(umidade);
    print('📊 Nova umidade: ${umidade.toStringAsFixed(1)}%');
  }

  void pararSensores() {
    _timerTemperatura?.cancel();
    _timerUmidade?.cancel();
    _timerTemperatura = null;
    _timerUmidade = null;
    
    _pararMonitoramentoGiroscopio();
    
    // Reseta valores
    _houveMovimento = false;
    _ultimaLeituraGiroscopio = 0.0;
    
    print('⏹️ Sensores parados');
  }
}