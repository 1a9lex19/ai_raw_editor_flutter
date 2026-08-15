import 'dart:math' as math;
import 'package:image/image.dart' as img;

class AutoSettings {
  final double exposure;
  final double contrast;
  final double highlights;
  final double shadows;
  final double temperature;

  const AutoSettings({
    required this.exposure,
    required this.contrast,
    required this.highlights,
    required this.shadows,
    required this.temperature,
  });
}

class PhotoProcessor {
  static img.Image process(
    img.Image source, {
    required double exposure,
    required double contrast,
    required double highlights,
    required double shadows,
    required double temperature,
  }) {
    final out = source.clone();

    // Exposure is applied multiplicatively in linear-ish RGB space.
    final exposureFactor = math.pow(2, exposure).toDouble();

    for (final p in out) {
      double r = p.r.toDouble() / 255.0;
      double g = p.g.toDouble() / 255.0;
      double b = p.b.toDouble() / 255.0;

      r *= exposureFactor;
      g *= exposureFactor;
      b *= exposureFactor;

      // Shadow/highlight recovery around the middle point.
      final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      final shadowWeight = (1.0 - (lum / 0.55)).clamp(0.0, 1.0);
      final highlightWeight = ((lum - 0.45) / 0.55).clamp(0.0, 1.0);

      final shadowGain = 1.0 + (shadows / 100.0) * 0.75 * shadowWeight;
      final highlightGain = 1.0 - (highlights / 100.0) * 0.65 * highlightWeight;

      r *= shadowGain * highlightGain;
      g *= shadowGain * highlightGain;
      b *= shadowGain * highlightGain;

      // Contrast using a smooth midpoint transform.
      final c = contrast / 100.0;
      final factor = (259.0 * (c * 255.0 + 255.0)) /
          (255.0 * (259.0 - c * 255.0));
      r = ((factor * ((r * 255.0) - 128.0) + 128.0) / 255.0);
      g = ((factor * ((g * 255.0) - 128.0) + 128.0) / 255.0);
      b = ((factor * ((b * 255.0) - 128.0) + 128.0) / 255.0);

      // Simple white-balance temperature shift.
      final t = temperature / 100.0;
      r += 0.08 * t;
      b -= 0.08 * t;

      p
        ..r = _byte(r)
        ..g = _byte(g)
        ..b = _byte(b);
    }
    return out;
  }

  static AutoSettings autoSettings(img.Image image) {
    // Histogram-driven "AI-style" automatic edit. This is deterministic,
    // entirely on-device, and requires no cloud service or model download.
    double sum = 0;
    double sum2 = 0;
    double shadows = 0;
    double highlights = 0;
    int count = 0;

    final stepX = math.max(1, image.width ~/ 160);
    final stepY = math.max(1, image.height ~/ 160);

    for (int y = 0; y < image.height; y += stepY) {
      for (int x = 0; x < image.width; x += stepX) {
        final p = image.getPixel(x, y);
        final l = (0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b) / 255.0;
        sum += l;
        sum2 += l * l;
        if (l < 0.16) shadows++;
        if (l > 0.88) highlights++;
        count++;
      }
    }

    final mean = sum / math.max(1, count);
    final variance = math.max(0.0, sum2 / math.max(1, count) - mean * mean);
    final std = math.sqrt(variance);

    // Target a perceptually useful middle exposure.
    final exposure = ((0.48 - mean) * 2.3).clamp(-1.5, 1.5);
    final contrast = ((0.20 - std) * 260.0).clamp(-20.0, 28.0);

    final shadowRatio = shadows / math.max(1, count);
    final highlightRatio = highlights / math.max(1, count);

    final shadowRecovery = (shadowRatio * 170.0).clamp(0.0, 55.0);
    final highlightRecovery = (highlightRatio * 160.0).clamp(0.0, 55.0);

    return AutoSettings(
      exposure: exposure,
      contrast: contrast,
      shadows: shadowRecovery,
      highlights: highlightRecovery,
      temperature: 0,
    );
  }

  static int _byte(double v) => (v.clamp(0.0, 1.0) * 255.0).round();
}
