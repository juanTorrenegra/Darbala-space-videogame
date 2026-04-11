// utils/game_utils.dart
import 'dart:math';
import 'package:flame/game.dart';

import 'package:flutter/services.dart';

// Funciones matemáticas y de utilidad para el juego
Vector2 calculateShootPosition(
  Vector2 entityPosition,
  double angle,
  Vector2 entitySize,
  double offsetDistance,
) {
  final offset = Vector2(
    cos(angle) * (entitySize.x / 2 + offsetDistance),
    sin(angle) * (entitySize.y / 2 + offsetDistance),
  );
  return entityPosition + offset;
}

// Conversión de grados a radianes (más intuitivo)
double degreesToRadians(double degrees) => degrees * pi / 180;

// Conversión de radianes a grados (para debugging)
double radiansToDegrees(double radians) => radians * 180 / pi;

// Calcula distancia entre dos puntos
double distanceBetween(Vector2 a, Vector2 b) => (a - b).length;

// Calcula ángulo entre dos puntos
double angleBetween(Vector2 a, Vector2 b) => atan2(b.y - a.y, b.x - a.x);

// Interpolación lineal entre dos valores
double lerp(double a, double b, double t) => a + (b - a) * t;

// Interpolación lineal para Vector2 - CORREGIDA
Vector2 vectorLerp(Vector2 a, Vector2 b, double t) {
  return Vector2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
}

// Limita un valor entre mínimo y máximo
double clamp(double value, double min, double max) => value < min
    ? min
    : value > max
    ? max
    : value;

class FontLoaderUtil {
  // Función para cargar una fuente desde una ruta de asset y registrarla con un nombre
  static Future<void> loadAndRegisterFont(
    String fontFamilyName,
    String assetPath,
  ) async {
    try {
      // 1. Cargar los bytes de datos de la fuente desde los assets
      final ByteData fontData = await rootBundle.load(assetPath);
      // 2. Crear un FontLoader con el nombre de familia que quieras usar
      final FontLoader fontLoader = FontLoader(fontFamilyName);
      // 3. Darle los datos de la fuente al FontLoader
      fontLoader.addFont(Future.value(fontData));
      // 4. ¡Registrar la fuente! Ahora se puede usar con fontFamily: 'MiNombre'
      await fontLoader.load();

      print('Fuente cargada exitosamente: $fontFamilyName');
    } catch (e) {
      print('Error cargando la fuente $fontFamilyName: $e');
    }
  }

  // Función de ejemplo para probar varias fuentes rápidamente
  static Future<void> loadAllFontsForTesting() async {
    Map<String, String> fontsToTest = {
      'Ava': 'assets/fonts/ava.ttf',
      'Futuristic1': 'assets/fonts/futuristic1.ttf',
      'Futuristic2': 'assets/fonts/futuristic2.ttf',
      'Inclinado': 'assets/fonts/inclinadoFuturistic.ttf',
      'Megatrans': 'assets/fonts/megatrans.otf',
      'Ortogonal': 'assets/fonts/ortogonal.otf',
      'Tintanium': 'assets/fonts/tintanium.ttf',
      'steel700': 'assets/fonts/steel700.ttf',
    };

    // Cargar cada fuente
    for (var entry in fontsToTest.entries) {
      await loadAndRegisterFont(entry.key, entry.value);
    }
  }
}
