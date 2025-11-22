#!/usr/bin/env python3
"""
Serviço ALARMS - Sistema de Notificações
Monitora alertas do CAT e envia notificações para o app
"""

import paho.mqtt.client as mqtt
from datetime import datetime
import json

# Configurações do Broker
BROKER_HOST = "localhost"
BROKER_PORT = 1883

# Tópicos MQTT
TOPIC_ALERTAS_CAT = "caldeira/alertas"
TOPIC_NOTIFICACOES = "caldeira/notificacoes"

class ServicoAlarms:
    def __init__(self):
        self.client = mqtt.Client(client_id="servico_alarms")
        self.contador_alertas = 0
        
        # Configurar callbacks
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        
    def on_connect(self, client, userdata, flags, rc):
        """Callback quando conecta ao broker"""
        if rc == 0:
            print("✅ Serviço ALARMS conectado ao broker!")
            # Inscreve-se no tópico de alertas do CAT
            client.subscribe(TOPIC_ALERTAS_CAT)
            print(f"🔔 Inscrito em: {TOPIC_ALERTAS_CAT}")
            print(f"📤 Publicará notificações em: {TOPIC_NOTIFICACOES}")
        else:
            print(f"❌ Falha na conexão. Código: {rc}")
    
    def on_message(self, client, userdata, msg):
        """Callback quando recebe alerta do CAT"""
        try:
            alerta_texto = msg.payload.decode().strip()
            self.contador_alertas += 1
            
            print(f"\n{'='*60}")
            print(f"🚨 ALERTA #{self.contador_alertas} RECEBIDO")
            print(f"📨 Mensagem: {alerta_texto}")
            print(f"⏰ Hora: {datetime.now().strftime('%H:%M:%S')}")
            print(f"{'='*60}")
            
            # Processa e envia notificação
            self._processar_alerta(alerta_texto)
            
        except Exception as e:
            print(f"❌ Erro ao processar alerta: {e}")
            import traceback
            traceback.print_exc()
    
    def _processar_alerta(self, alerta_texto):
        """Processa o alerta e envia notificação para o app"""
        
        # Determina tipo e severidade do alerta
        tipo_alerta = "INFO"
        severidade = "baixa"
        icone = "⚠️"
        
        if "TEMPERATURA ALTA" in alerta_texto:
            tipo_alerta = "TEMPERATURA_ALTA"
            severidade = "alta"
            icone = "🔥"
        elif "AUMENTO REPENTINO" in alerta_texto:
            tipo_alerta = "AUMENTO_REPENTINO"
            severidade = "crítica"
            icone = "⚡"
        
        # Cria payload da notificação em JSON
        notificacao = {
            "id": self.contador_alertas,
            "tipo": tipo_alerta,
            "severidade": severidade,
            "icone": icone,
            "mensagem": alerta_texto,
            "timestamp": datetime.now().isoformat(),
            "duracao": 8  # Duração do popup em segundos
        }
        
        # Converte para JSON
        payload = json.dumps(notificacao, ensure_ascii=False)
        
        # Publica notificação no broker
        self.client.publish(TOPIC_NOTIFICACOES, payload, qos=1)
        
        print(f"📤 Notificação enviada:")
        print(f"   Tipo: {tipo_alerta}")
        print(f"   Severidade: {severidade}")
        print(f"   Duração: 8 segundos")
        print()
    
    def iniciar(self):
        """Inicia o serviço"""
        print("🚀 Iniciando Serviço ALARMS...")
        print(f"📡 Broker: {BROKER_HOST}:{BROKER_PORT}")
        print(f"🔔 Escutando alertas de: {TOPIC_ALERTAS_CAT}")
        print(f"📤 Enviando notificações para: {TOPIC_NOTIFICACOES}")
        print("-" * 60)
        
        try:
            self.client.connect(BROKER_HOST, BROKER_PORT, 60)
            self.client.loop_forever()
        except KeyboardInterrupt:
            print("\n⏹️  Serviço ALARMS encerrado pelo usuário")
        except Exception as e:
            print(f"❌ Erro: {e}")
        finally:
            self.client.disconnect()

if __name__ == "__main__":
    servico = ServicoAlarms()
    servico.iniciar()