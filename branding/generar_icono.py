"""Genera el ícono de la app a partir del logo de la pensión (branding/logo_pension.jpg).

Recorta el círculo naranja del logo (sin el fondo mostaza, el aro beige ni la sombra)
y crea los recursos de Android:
- mipmap-*/ic_launcher.png: ícono clásico (logo redondo sobre fondo transparente);
- mipmap-*/ic_launcher_foreground.png: primer plano del ícono adaptativo (Android 8+),
  con el logo dentro de la zona visible; el fondo es el mismo naranja del logo
  (values/ic_launcher_background.xml), así se ve continuo en cualquier forma.

Uso (con Docker, sin instalar Python en la laptop), desde pension_app:
  docker run --rm -v "%cd%":/app -w /app python:3.12-slim sh -c \
    "pip install -q pillow && python branding/generar_icono.py"
"""
import math
from statistics import median

from PIL import Image, ImageDraw

ORIGEN = "branding/logo_pension.jpg"
RES = "android/app/src/main/res"
NARANJA = (211, 82, 43)   # #D3522B, el fondo del círculo del logo


def es_naranja(p):
    r, g, b = p[:3]
    return r > 185 and 60 < g < 110 and b < 70


def circulo(im):
    """Centro y radio del círculo naranja: desde afuera hacia adentro, en 72 direcciones."""
    w, h = im.size
    cx, cy = w / 2, h / 2
    radios, puntos = [], []
    for k in range(72):
        a = 2 * math.pi * k / 72
        for paso in range(int(min(w, h) / 2), 0, -1):
            x, y = int(cx + paso * math.cos(a)), int(cy + paso * math.sin(a))
            if 0 <= x < w and 0 <= y < h and es_naranja(im.getpixel((x, y))):
                puntos.append((x, y))
                break
    xs = sorted(p[0] for p in puntos)
    ys = sorted(p[1] for p in puntos)
    cx, cy = (xs[0] + xs[-1]) / 2, (ys[0] + ys[-1]) / 2
    radios = [math.hypot(x - cx, y - cy) for x, y in puntos]
    return cx, cy, median(radios)


def logo_redondo(im, cx, cy, r):
    """El círculo del logo como imagen cuadrada con transparencia fuera del círculo."""
    r = r - 3   # sin el borde del aro beige
    lado = round(2 * r)
    x0, y0 = round(cx - r), round(cy - r)
    recorte = im.crop((x0, y0, x0 + lado, y0 + lado)).convert("RGBA")
    mascara = Image.new("L", (lado * 4, lado * 4), 0)
    ImageDraw.Draw(mascara).ellipse([0, 0, lado * 4 - 1, lado * 4 - 1], fill=255)
    recorte.putalpha(mascara.resize((lado, lado), Image.LANCZOS))
    return recorte


def main():
    im = Image.open(ORIGEN).convert("RGB")
    cx, cy, r = circulo(im)
    print(f"Círculo del logo: centro ({cx:.0f}, {cy:.0f}), radio {r:.0f}")
    logo = logo_redondo(im, cx, cy, r)

    clasico = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for densidad, lado in clasico.items():
        logo.resize((lado, lado), Image.LANCZOS).save(f"{RES}/mipmap-{densidad}/ic_launcher.png")

    # Adaptativo: lienzo de 108 dp; el sistema muestra los 72 dp centrales.
    adaptativo = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    for densidad, lado in adaptativo.items():
        lienzo = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
        d = round(lado * 72 / 108)
        lienzo.alpha_composite(logo.resize((d, d), Image.LANCZOS), ((lado - d) // 2, (lado - d) // 2))
        lienzo.save(f"{RES}/mipmap-{densidad}/ic_launcher_foreground.png")
    print("Íconos generados en", RES)


if __name__ == "__main__":
    main()
