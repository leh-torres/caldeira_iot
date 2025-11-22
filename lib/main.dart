import 'package:flutter/material.dart';
import 'mqtt_service.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caldeira App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MonitorScreen(),
    );
  }
}

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final MqttService mqttService = MqttService();

  double temperatura = 0.0;
  double umidade = 0.0;
  bool conectado = false;
  bool sensoresAtivos = false;
  String ultimoAlerta = '';
  
  int segundosRestantes = 60;
  Timer? _timerContador;

  @override
  void initState() {
    super.initState();

    mqttService.onConnectionChanged = (bool isConnected) {
      if (mounted) {
        setState(() {
          conectado = isConnected;
          if (!isConnected) {
            sensoresAtivos = false;
            temperatura = 0.0;
            umidade = 0.0;
            _pararContador();
          }
        });
      }
    };

    mqttService.onTemperaturaAtualizada = (double novaTemperatura) {
      if (mounted) {
        setState(() {
          temperatura = novaTemperatura;
        });
      }
    };

    mqttService.onUmidadeAtualizada = (double novaUmidade) {
      if (mounted) {
        setState(() {
          umidade = novaUmidade;
        });
      }
    };
    
    mqttService.onAlertaRecebido = (String alerta) {
      if (mounted) {
        setState(() {
          ultimoAlerta = alerta;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(alerta),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    };
    
    mqttService.onNotificacaoRecebida = (Map<String, dynamic> notificacao) {
      if (mounted) {
        _mostrarPopupNotificacao(notificacao);
      }
    };
  }

  void _iniciarContador() {
    _pararContador();
    
    setState(() {
      segundosRestantes = 60;
    });
    
    _timerContador = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (segundosRestantes > 0) {
            segundosRestantes--;
          } else {
            segundosRestantes = 60;
          }
        });
      }
    });
  }

  void _pararContador() {
    _timerContador?.cancel();
    _timerContador = null;
    if (mounted) {
      setState(() {
        segundosRestantes = 60;
      });
    }
  }

  Future<void> toggleConexao() async {
    if (conectado) {
      mqttService.disconnect();
      setState(() {
        conectado = false;
        sensoresAtivos = false;
        temperatura = 0.0;
        umidade = 0.0;
      });
      _pararContador();
    } else {
      bool sucesso = await mqttService.connect();
      if (!sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Falha ao conectar')),
        );
      }
    }
  }

  void toggleSensores() {
    if (!conectado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Conecte ao broker primeiro!')),
      );
      return;
    }

    if (sensoresAtivos) {
      mqttService.pararSensores();
      _pararContador();
      setState(() {
        sensoresAtivos = false;
        temperatura = 0.0;
        umidade = 0.0;
      });
    } else {
      mqttService.iniciarSensorTemperatura();
      mqttService.iniciarSensorUmidade();
      _iniciarContador();
      setState(() {
        sensoresAtivos = true;
      });
    }
  }

  void _mostrarPopupNotificacao(Map<String, dynamic> notificacao) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return NotificacaoPopup(
          notificacao: notificacao,
        );
      },
    );
  }

  @override
  void dispose() {
    _pararContador();
    mqttService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor de Caldeira'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBigButton(
                  isActive: conectado,
                  activeIcon: Icons.wifi_off,
                  inactiveIcon: Icons.wifi,
                  activeLabel: 'Desconectar',
                  inactiveLabel: 'Conectar',
                  activeColor: Colors.red,
                  inactiveColor: Colors.green,
                  onTap: toggleConexao,
                ),
                _buildBigButton(
                  isActive: sensoresAtivos,
                  activeIcon: Icons.stop_circle,
                  inactiveIcon: Icons.play_circle_fill,
                  activeLabel: 'Parar',
                  inactiveLabel: 'Iniciar',
                  activeColor: Colors.orange,
                  inactiveColor: Colors.blue,
                  onTap: toggleSensores,
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildStatusBox(
              title: 'Status da Conexão',
              status: conectado ? 'Conectado ao broker' : 'Desconectado',
              isActive: conectado,
              icon: conectado ? Icons.check_circle : Icons.cancel,
            ),

            const SizedBox(height: 12),

            _buildStatusBoxWithTimer(
              title: 'Status dos Sensores',
              status: sensoresAtivos ? 'Sensores ativos' : 'Sensores inativos',
              isActive: sensoresAtivos,
              icon: sensoresAtivos ? Icons.sensors : Icons.sensors_off,
              showTimer: sensoresAtivos,
              segundos: segundosRestantes,
            ),

            const SizedBox(height: 16),

            const Divider(thickness: 2),

            const SizedBox(height: 16),

            _buildSensorCard(
              label: 'Temperatura',
              value: temperatura > 0 
                  ? '${temperatura.toStringAsFixed(1)}°C'
                  : '--',
              icon: Icons.thermostat,
              color: Colors.red,
            ),

            const SizedBox(height: 12),

            _buildSensorCard(
              label: 'Umidade',
              value: umidade > 0 
                  ? '${umidade.toStringAsFixed(1)}%'
                  : '--',
              icon: Icons.water_drop,
              color: Colors.blue,
            ),
            
            if (ultimoAlerta.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ultimoAlerta,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBigButton({
    required bool isActive,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String activeLabel,
    required String inactiveLabel,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    final icon = isActive ? activeIcon : inactiveIcon;
    final label = isActive ? activeLabel : inactiveLabel;
    final color = isActive ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBox({
    required String title,
    required String status,
    required bool isActive,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
        border: Border.all(
          color: isActive ? Colors.green : Colors.grey,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: isActive ? Colors.green : Colors.grey, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    color: isActive ? Colors.green.shade900 : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBoxWithTimer({
    required String title,
    required String status,
    required bool isActive,
    required IconData icon,
    required bool showTimer,
    required int segundos,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
        border: Border.all(
          color: isActive ? Colors.green : Colors.grey,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: isActive ? Colors.green : Colors.grey, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    color: isActive ? Colors.green.shade900 : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (showTimer) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.timer, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Próxima coleta: ${segundos}s',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NotificacaoPopup extends StatefulWidget {
  final Map<String, dynamic> notificacao;

  const NotificacaoPopup({Key? key, required this.notificacao}) : super(key: key);

  @override
  State<NotificacaoPopup> createState() => _NotificacaoPopupState();
}

class _NotificacaoPopupState extends State<NotificacaoPopup> {
  int segundosRestantes = 8;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    iniciarTimer();
  }

  void iniciarTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() {
          segundosRestantes--;
        });

        if (segundosRestantes <= 0) {
          timer?.cancel();
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Color _getCorSeveridade() {
    final severidade = widget.notificacao['severidade'] ?? 'baixa';
    switch (severidade) {
      case 'crítica':
        return Colors.red.shade700;
      case 'alta':
        return Colors.orange.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  IconData _getIconeSeveridade() {
    final severidade = widget.notificacao['severidade'] ?? 'baixa';
    switch (severidade) {
      case 'crítica':
        return Icons.warning_amber_rounded;
      case 'alta':
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cor = _getCorSeveridade();
    final icone = _getIconeSeveridade();
    final mensagem = widget.notificacao['mensagem'] ?? 'Alerta';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 500),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icone,
                      size: 48,
                      color: cor,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            Text(
              'ALERTA DO SISTEMA',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cor,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cor.withOpacity(0.3)),
              ),
              child: Text(
                mensagem,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade800,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: segundosRestantes / 8,
                    strokeWidth: 6,
                    backgroundColor: cor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(cor),
                  ),
                ),
                Text(
                  '$segundosRestantes',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: cor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              'Fechando automaticamente...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  timer?.cancel();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'FECHAR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}