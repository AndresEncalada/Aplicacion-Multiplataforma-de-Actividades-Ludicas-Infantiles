"""
Descarga e instala los modelos de IA necesarios para el backend.
Ejecutar desde la raíz del backend: uv run python scripts/instalar_modelos.py

Descarga total aproximada: ~1.5 GB
  - Whisper.cpp small (~465 MB)
  - Qwen 2.5 1.5B GGUF (~1.06 GB)
"""
import os
import urllib.request
import zipfile
from pathlib import Path

MODELOS = {
    "whisper": {
        "url": "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin",
        "archivo": "modelos_whisper/ggml-small.bin",
        "carpeta_destino": "modelos_whisper",
        "descripcion": "Whisper.cpp small (transcripcion de audio en espanol)"
    },
    "llm": {
        "url": "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf",
        "archivo": "modelos_llm/qwen2.5-1.5b-instruct-q4_k_m.gguf",
        "carpeta_destino": "modelos_llm",
        "descripcion": "Qwen 2.5 1.5B (modelo de lenguaje local)"
    }
}

def descargar_archivo(url, destino):
    print(f"Descargando {destino}...")

    def progreso(bloque_num, tamaño_bloque, tamaño_total):
        descargado = bloque_num * tamaño_bloque
        if tamaño_total > 0:
            porcentaje = min(100, descargado * 100 / tamaño_total)
            mb_desc = descargado / (1024 * 1024)
            mb_total = tamaño_total / (1024 * 1024)
            print(f"\r   {porcentaje:.1f}% ({mb_desc:.1f}/{mb_total:.1f} MB)", end="", flush=True)

    try:
        urllib.request.urlretrieve(url, destino, reporthook=progreso)
        print("\n   Descarga completada")
        return True
    except Exception as e:
        print(f"\n   Error: {e}")
        return False

def instalar_modelo(nombre, info):
    print(f"\n{'='*60}")
    print(f"Instalando: {info['descripcion']}")
    print(f"{'='*60}")

    Path(info['carpeta_destino']).mkdir(parents=True, exist_ok=True)
    archivo_destino = info['archivo']

    if Path(archivo_destino).exists():
        print(f"   El archivo ya existe: {archivo_destino}")
        respuesta = input("   Re-descargar? (s/n): ").strip().lower()
        if respuesta != 's':
            print("   Saltando descarga")
            return True

    if not descargar_archivo(info['url'], archivo_destino):
        return False

    if archivo_destino.endswith('.zip'):
        print(f"   Extrayendo {archivo_destino}...")
        try:
            with zipfile.ZipFile(archivo_destino, 'r') as zip_ref:
                zip_ref.extractall(info['carpeta_destino'])
            print("   Extraccion completada")
            os.remove(archivo_destino)
        except Exception as e:
            print(f"   Error al extraer: {e}")
            return False

    return True

def main():
    print("\n" + "="*60)
    print("INSTALADOR DE MODELOS DE IA")
    print("="*60)
    print("\nDescargara los modelos grandes que no se incluyen en el repo:")
    for info in MODELOS.values():
        print(f"  - {info['descripcion']}")
    print("\nDescarga total: ~1.5 GB. Asegurate de tener conexion estable.\n")

    respuesta = input("Continuar? (s/n): ").strip().lower()
    if respuesta != 's':
        print("Cancelado")
        return

    exitosos = sum(1 for n, i in MODELOS.items() if instalar_modelo(n, i))

    print("\n" + "="*60)
    print(f"Modelos instalados: {exitosos}/{len(MODELOS)}")
    if exitosos == len(MODELOS):
        print("\nTodo listo. Ejecuta: uv run python main.py")
    print("="*60 + "\n")

if __name__ == "__main__":
    main()
