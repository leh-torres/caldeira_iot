#!/usr/bin/env python3
"""
Serviço CAT - Continuous Analysis of Temperature
Monitora temperaturas do broker MQTT e gera alertas
"""

import paho.mqtt.client as mqtt
from datetime import datetime, timedelta
from collections import deque
import time
import statistics

# Configurações do Broker
BROKER_HOST = "localhost"  # Mude se necessário
BROKER_PORT = 1883

# Tópicos MQTT
TOPIC_TEMPERATURA = "caldeira/temperatura"
TOPIC_ALERTAS = "caldeira/alertas"

# Configurações de análise
JANELA_TEMPO = 120  
LIMIAR_AUMENTO_REPENTINO = 5.0  
LIMIAR_TEMPERATURA_ALTA = 200.0 

class ServicoCAT:
    def __init__(self):
        self.client = mqtt.Client(client_id="servico_cat")
        self.leituras = deque()  
        self.medias_anteriores = deque(maxlen=2)  
        
        # Configurar callbacks
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        
    def on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            print("✅ Serviço CAT conectado ao broker!")
            client.subscribe(TOPIC_TEMPERATURA)
            print(f"🔔 Inscrito em: {TOPIC_TEMPERATURA}")
        else:
            print(f"❌ Falha na conexão. Código: {rc}")
    
    def on_message(self, client, userdata, msg):
    
        try:
            # Extrai temperatura da mensagem
            temperatura_str = msg.payload.decode().strip()
            temperatura = float(temperatura_str)
            timestamp = datetime.now()
            
            # Adiciona leitura
            self.leituras.append((timestamp, temperatura))
            print(f"📊 Nova leitura: {temperatura:.1f}°C às {timestamp.strftime('%H:%M:%S')}")
            print(f"   Total de leituras armazenadas: {len(self.leituras)}")
            
            # Remove leituras antigas (fora da janela de 120s)
            self._limpar_leituras_antigas()
            
            # Analisa e gera alertas se necessário
            self._analisar_temperatura(temperatura)
            
        except ValueError as e:
            print(f"⚠️ Erro ao converter temperatura: '{msg.payload.decode()}' - {e}")
        except Exception as e:
            print(f"❌ Erro inesperado: {e}")
            import traceback
            traceback.print_exc()
    
    def _limpar_leituras_antigas(self):
        """Remove leituras mais antigas que 120 segundos"""
        agora = datetime.now()
        limite_tempo = agora - timedelta(seconds=JANELA_TEMPO)
        
        # Remove elementos antigos do início da fila
        while self.leituras and self.leituras[0][0] < limite_tempo:
            self.leituras.popleft()
    
    def _calcular_media(self):
        """Calcula a média das temperaturas nos últimos 120s"""
        if not self.leituras:
            return None
        
        temperaturas = [temp for _, temp in self.leituras]
        media = statistics.mean(temperaturas)
        
        print(f"📈 Média dos últimos {len(temperaturas)} valores: {media:.1f}°C")
        return media
    
    def _analisar_temperatura(self, temperatura_atual):
        """Analisa temperatura e gera alertas"""
        
        # Alerta 1: Temperatura Alta
        if temperatura_atual > LIMIAR_TEMPERATURA_ALTA:
            mensagem = f"TEMPERATURA ALTA: {temperatura_atual:.1f}°C (Limiar: {LIMIAR_TEMPERATURA_ALTA}°C)"
            self._publicar_alerta(mensagem)
            print(f"🚨 {mensagem}")
        
        # Calcula média atual
        media_atual = self._calcular_media()
        if media_atual is None:
            return
        
        # Adiciona média à lista
        self.medias_anteriores.append(media_atual)
        
        # Alerta 2: Aumento Repentino (precisa de pelo menos 2 médias)
        if len(self.medias_anteriores) >= 2:
            media_anterior = self.medias_anteriores[-2]
            media_atual = self.medias_anteriores[-1]
            diferenca = media_atual - media_anterior
            
            if diferenca > LIMIAR_AUMENTO_REPENTINO:
                mensagem = (f"AUMENTO REPENTINO: +{diferenca:.1f}°C "
                          f"(de {media_anterior:.1f}°C para {media_atual:.1f}°C)")
                self._publicar_alerta(mensagem)
                print(f"🔥 {mensagem}")
    
    def _publicar_alerta(self, mensagem):
        """Publica alerta no broker"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        payload = f"[{timestamp}] {mensagem}"
        
        self.client.publish(TOPIC_ALERTAS, payload, qos=1)
        print(f"📤 Alerta publicado: {mensagem}")
    
    def iniciar(self):
        """Inicia o serviço"""
        print("🚀 Iniciando Serviço CAT...")
        print(f"📡 Broker: {BROKER_HOST}:{BROKER_PORT}")
        print(f"⏱️  Janela de análise: {JANELA_TEMPO}s")
        print(f"🔥 Limiar aumento repentino: {LIMIAR_AUMENTO_REPENTINO}°C")
        print(f"🌡️  Limiar temperatura alta: {LIMIAR_TEMPERATURA_ALTA}°C")
        print("-" * 50)
        
        try:
            self.client.connect(BROKER_HOST, BROKER_PORT, 60)
            self.client.loop_forever()
        except KeyboardInterrupt:
            print("\n⏹️  Serviço CAT encerrado pelo usuário")
        except Exception as e:
            print(f"❌ Erro: {e}")
        finally:
            self.client.disconnect()

if __name__ == "__main__":
    servico = ServicoCAT()
    servico.iniciar()