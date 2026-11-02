"""
Conector Cliente TCP hacia el servidor de Arduino en la Raspberry Pi (server.py :41798).
Diseñado en modo 'Fire-and-Forget' (no bloqueante, timeout de 150 ms) con tolerancia total a fallos:
- Si la Raspberry Pi y el Arduino están conectados, transmite los comandos reales del protocolo
  (A1, A2, A3, MD4, MI5, CA3, OD2, BR1, CC, NA, TT).
- Si no están conectados físicamente, registra el envío en consola e historial sin lanzar errores
  ni ralentizar los FPS de visión por computadora.
"""
import asyncio
import os
import socket
import time
from typing import Any, Dict, List

ARDUINO_HOST = os.environ.get("FELPUDO_ARDUINO_HOST", "192.168.1.200")
ARDUINO_PORT = int(os.environ.get("FELPUDO_ARDUINO_PORT", "41798"))
ARDUINO_TIMEOUT_SEC = float(os.environ.get("FELPUDO_ARDUINO_TIMEOUT", "0.15"))


class ArduinoClient:
    def __init__(self, host: str = ARDUINO_HOST, port: int = ARDUINO_PORT, timeout: float = ARDUINO_TIMEOUT_SEC):
        self.host = host
        self.port = port
        self.timeout = timeout
        self.disponible = False
        self.ultimo_comando = None
        self.ultimo_envio_ts = None
        self.historial_comandos: List[Dict[str, Any]] = []

    def _enviar_sync(self, codigo: str, descripcion: str = "") -> bool:
        """Envía el comando por socket TCP con timeout ultra corto. Nunca propaga excepciones."""
        ts_str = time.strftime("%H:%M:%S")
        exito = False
        try:
            with socket.create_connection((self.host, self.port), timeout=self.timeout) as sock:
                sock.settimeout(self.timeout)
                # server.py envía 'BIENVENIDO\n' al conectar
                try:
                    sock.recv(64)
                except Exception:
                    pass
                sock.sendall(codigo.encode("utf-8"))
                exito = True
                self.disponible = True
        except Exception:
            self.disponible = False
            exito = False

        self.ultimo_comando = codigo
        self.ultimo_envio_ts = ts_str
        registro = {
            "hora": ts_str,
            "comando": codigo,
            "descripcion": descripcion,
            "entregado_fisicamente": exito,
        }
        self.historial_comandos.append(registro)
        if len(self.historial_comandos) > 50:
            self.historial_comandos = self.historial_comandos[-50:]

        estado_txt = "ENTREGADO" if exito else "SIMULADO (Arduino desconectado)"
        desc_txt = f" ({descripcion})" if descripcion else ""
        print(f"[ARDUINO TCP {self.host}:{self.port}] Comando '{codigo}'{desc_txt} -> {estado_txt}")
        return exito

    async def enviar_comando(self, codigo: str, descripcion: str = "") -> None:
        """Dispara el envío del comando al Arduino en un hilo secundario sin bloquear el event loop."""
        loop = asyncio.get_running_loop()
        loop.run_in_executor(None, self._enviar_sync, codigo, descripcion)

    def estado(self) -> Dict[str, Any]:
        return {
            "host": self.host,
            "port": self.port,
            "conectado": self.disponible,
            "ultimo_comando": self.ultimo_comando,
            "ultimo_envio": self.ultimo_envio_ts,
            "modo": "Hardware Activo" if self.disponible else "Tolerante / Simulado (No bloqueante)",
        }


# Instancia global compartida
arduino_client = ArduinoClient()
