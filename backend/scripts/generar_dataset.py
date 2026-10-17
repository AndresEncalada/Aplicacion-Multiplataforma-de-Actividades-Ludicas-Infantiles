"""
Genera el dataset sintético de pictogramas con augmentación.
Ejecutar desde la raíz del backend: uv run python scripts/generar_dataset.py

Toma los 18 PNGs originales de pictogramas_originales/ y genera imágenes
con fondos realistas y augmentación para entrenamiento.
Salida: dataset_pictogramas/ (train/ + val/)
"""
import cv2
import numpy as np
import os
import random


class DatasetGenerator:
    def __init__(self, source_folder="pictogramas_originales", output_folder="dataset_pictogramas"):
        self.source_folder = source_folder
        self.output_folder = output_folder
        self.train_per_class = 30
        self.val_per_class = 10

        for split in ['train', 'val']:
            for file in os.listdir(source_folder):
                if file.endswith(('.png', '.jpg', '.jpeg')):
                    class_name = os.path.splitext(file)[0].lower()
                    os.makedirs(os.path.join(output_folder, split, class_name), exist_ok=True)

    def crear_fondo_realista(self, size):
        h, w = size
        tipo = random.choice(['papel_blanco', 'papel_beige', 'mesa_madera', 'piso_gris', 'transparente'])

        if tipo == 'papel_blanco':
            fondo = np.ones((h, w, 3), dtype=np.uint8) * random.randint(240, 255)
            ruido = np.random.normal(0, 3, (h, w, 3))
            fondo = np.clip(fondo + ruido, 0, 255).astype(np.uint8)
        elif tipo == 'papel_beige':
            fondo = np.ones((h, w, 3), dtype=np.uint8)
            fondo[:, :, 0] = random.randint(220, 240)
            fondo[:, :, 1] = random.randint(210, 230)
            fondo[:, :, 2] = random.randint(190, 210)
        elif tipo == 'mesa_madera':
            fondo = np.ones((h, w, 3), dtype=np.uint8)
            color_base = [random.randint(180, 210), random.randint(150, 180), random.randint(120, 150)]
            fondo[:, :] = color_base
            for _ in range(random.randint(5, 15)):
                y = random.randint(0, h)
                grosor = random.randint(1, 3)
                color_veta = [c - random.randint(10, 30) for c in color_base]
                cv2.line(fondo, (0, y), (w, y), color_veta, grosor)
            ruido = np.random.normal(0, 5, (h, w, 3))
            fondo = np.clip(fondo + ruido, 0, 255).astype(np.uint8)
        elif tipo == 'piso_gris':
            fondo = np.ones((h, w, 3), dtype=np.uint8) * random.randint(180, 220)
            ruido = np.random.normal(0, 8, (h, w, 3))
            fondo = np.clip(fondo + ruido, 0, 255).astype(np.uint8)
        else:
            fondo = np.ones((h, w, 3), dtype=np.uint8) * 255

        return fondo

    def aplicar_augmentation(self, img_bgr, alpha_channel, modo='train'):
        h, w = img_bgr.shape[:2]

        if modo == 'train':
            random.seed(random.randint(0, 10000))
        else:
            random.seed(random.randint(10001, 20000))

        augmented_bgr = img_bgr.copy()
        augmented_alpha = alpha_channel.copy()

        if random.random() < 0.7:
            angle = random.uniform(-25, 25)
            M = cv2.getRotationMatrix2D((w/2, h/2), angle, 1)
            augmented_bgr = cv2.warpAffine(augmented_bgr, M, (w, h), borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0))
            augmented_alpha = cv2.warpAffine(augmented_alpha, M, (w, h), borderMode=cv2.BORDER_CONSTANT, borderValue=0)

        if random.random() < 0.8:
            scale = random.uniform(0.7, 1.3)
            new_w, new_h = int(w * scale), int(h * scale)
            augmented_bgr = cv2.resize(augmented_bgr, (new_w, new_h))
            augmented_alpha = cv2.resize(augmented_alpha, (new_w, new_h))

            canvas_bgr = np.zeros((h, w, 3), dtype=np.uint8)
            canvas_alpha = np.zeros((h, w), dtype=np.uint8)
            x_offset = (w - new_w) // 2
            y_offset = (h - new_h) // 2
            x1_dst = max(0, -x_offset)
            y1_dst = max(0, -y_offset)
            x2_dst = min(new_w, w - x_offset)
            y2_dst = min(new_h, h - y_offset)
            x1_src = max(0, x_offset)
            y1_src = max(0, y_offset)
            x2_src = x1_src + (x2_dst - x1_dst)
            y2_src = y1_src + (y2_dst - y1_dst)

            if x2_dst > x1_dst and y2_dst > y1_dst:
                canvas_bgr[y1_src:y2_src, x1_src:x2_src] = augmented_bgr[y1_dst:y2_dst, x1_dst:x2_dst]
                canvas_alpha[y1_src:y2_src, x1_src:x2_src] = augmented_alpha[y1_dst:y2_dst, x1_dst:x2_dst]

            augmented_bgr = canvas_bgr
            augmented_alpha = canvas_alpha

        if random.random() < 0.8:
            brightness = random.randint(-30, 30)
            hsv = cv2.cvtColor(augmented_bgr, cv2.COLOR_BGR2HSV).astype(np.float32)
            hsv[:, :, 2] = np.clip(hsv[:, :, 2] + brightness, 0, 255)
            augmented_bgr = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2BGR)

        if random.random() < 0.4:
            kernel_size = random.choice([3, 5])
            augmented_bgr = cv2.GaussianBlur(augmented_bgr, (kernel_size, kernel_size), 0)

        if random.random() < 0.5:
            noise = np.random.normal(0, random.uniform(3, 10), augmented_bgr.shape)
            augmented_bgr = np.clip(augmented_bgr + noise, 0, 255).astype(np.uint8)

        if random.random() < 0.6:
            quality = random.randint(60, 95)
            _, encoded = cv2.imencode('.jpg', augmented_bgr, [cv2.IMWRITE_JPEG_QUALITY, quality])
            augmented_bgr = cv2.imdecode(encoded, cv2.IMREAD_COLOR)

        fondo = self.crear_fondo_realista((h, w))
        alpha_norm = augmented_alpha.astype(np.float32) / 255.0
        alpha_norm = np.stack([alpha_norm] * 3, axis=-1)
        resultado = (fondo * (1 - alpha_norm) + augmented_bgr * alpha_norm).astype(np.uint8)

        return resultado

    def generar_dataset(self):
        print("=" * 60)
        print("GENERADOR DE DATASET SINTETICO CON FONDOS REALISTAS")
        print("=" * 60)

        files = [f for f in os.listdir(self.source_folder) if f.endswith(('.png', '.jpg', '.jpeg'))]
        if not files:
            print(f"No se encontraron imagenes en {self.source_folder}")
            return

        print(f"Pictogramas: {len(files)}")
        print(f"Total a generar: {len(files) * (self.train_per_class + self.val_per_class)} imagenes\n")

        for file in files:
            class_name = os.path.splitext(file)[0].lower()
            source_path = os.path.join(self.source_folder, file)
            print(f"  Procesando: {class_name}")

            img_rgba = cv2.imread(source_path, cv2.IMREAD_UNCHANGED)
            if img_rgba is None:
                print(f"  Error al leer {file}")
                continue

            if img_rgba.shape[2] == 4:
                img_bgr = img_rgba[:, :, :3]
                alpha_channel = img_rgba[:, :, 3]
            else:
                img_bgr = img_rgba
                alpha_channel = np.ones(img_bgr.shape[:2], dtype=np.uint8) * 255

            img_bgr = cv2.resize(img_bgr, (256, 256))
            alpha_channel = cv2.resize(alpha_channel, (256, 256))

            train_folder = os.path.join(self.output_folder, 'train', class_name)
            for i in range(self.train_per_class):
                augmented = self.aplicar_augmentation(img_bgr, alpha_channel, modo='train')
                cv2.imwrite(os.path.join(train_folder, f"img_{i+1:03d}.jpg"), augmented)

            val_folder = os.path.join(self.output_folder, 'val', class_name)
            for i in range(self.val_per_class):
                augmented = self.aplicar_augmentation(img_bgr, alpha_channel, modo='val')
                cv2.imwrite(os.path.join(val_folder, f"val_{i+1:03d}.jpg"), augmented)

            print(f"    {self.train_per_class} train + {self.val_per_class} val")

        total = len(files) * (self.train_per_class + self.val_per_class)
        print(f"\nDataset generado en {self.output_folder}/ ({total} imagenes)")
        print("Siguiente: uv run python scripts/entrenar_pictogramas.py")


if __name__ == "__main__":
    generator = DatasetGenerator(
        source_folder="pictogramas_originales",
        output_folder="dataset_pictogramas"
    )
    generator.generar_dataset()
