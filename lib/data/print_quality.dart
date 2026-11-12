part of '../main.dart';

// Approximation for a full rectangular image fitted to a print; not a blur detector.
double estimatePrintDpi(
    int width, int height, double widthCm, double heightCm) {
  if (width <= 0 || height <= 0 || widthCm <= 0 || heightCm <= 0) return 0;
  return 2.54 *
      math.max(math.min(width / widthCm, height / heightCm),
          math.min(width / heightCm, height / widthCm));
}

String qualityLabel(double dpi) => dpi >= 300
    ? 'Высокое разрешение'
    : dpi >= 180
        ? 'Подойдёт по разрешению'
        : 'Может быть нечётким';
