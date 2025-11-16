import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageProcessingService {
  /// Cartoonizes an image by applying smoothing, posterization, and edge detection
  /// Takes image bytes and returns processed bytes
  static Future<Uint8List> cartoonizeImage(Uint8List imageBytes) async {
    // Decode the image
    img.Image? image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Resize if too large (max 800px)
    const maxDim = 800;
    if (image.width > maxDim || image.height > maxDim) {
      final scale =
          maxDim / (image.width > image.height ? image.width : image.height);
      final newWidth = (image.width * scale).round();
      final newHeight = (image.height * scale).round();
      image = img.copyResize(image, width: newWidth, height: newHeight);
    }

    // Apply smoothing (bilateral-like effect)
    image = img.gaussianBlur(image, radius: 3);

    // Posterize (reduce color levels)
    image = _posterize(image, levels: 6);

    // Edge detection and overlay
    final edges = _detectEdges(image);
    image = _compositeEdges(image, edges);

    // Encode back to PNG
    return Uint8List.fromList(img.encodePng(image));
  }

  /// Posterize the image by reducing color levels
  static img.Image _posterize(img.Image image, {int levels = 6}) {
    final result = image.clone();

    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        final a = pixel.a;

        // Posterize each channel
        final newR =
            ((r / 255 * (levels - 1)).round() * (255 / (levels - 1))).round();
        final newG =
            ((g / 255 * (levels - 1)).round() * (255 / (levels - 1))).round();
        final newB =
            ((b / 255 * (levels - 1)).round() * (255 / (levels - 1))).round();

        result.setPixelRgba(x, y, newR, newG, newB, a.toInt());
      }
    }

    return result;
  }

  /// Simple edge detection using Sobel operator
  static img.Image _detectEdges(img.Image image) {
    // Convert to grayscale
    final gray = img.grayscale(image.clone());
    final edges = img.Image(width: image.width, height: image.height);

    // Sobel kernels
    final sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1]
    ];

    final sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1]
    ];

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        double gx = 0;
        double gy = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = gray.getPixel(x + kx, y + ky);
            final value = pixel.r / 255.0;
            gx += value * sobelX[ky + 1][kx + 1];
            gy += value * sobelY[ky + 1][kx + 1];
          }
        }

        final magnitude = (255 * (gx * gx + gy * gy).clamp(0, 1)).round();
        edges.setPixelRgba(x, y, magnitude, magnitude, magnitude, 255);
      }
    }

    return edges;
  }

  /// Composite edges over the posterized image
  static img.Image _compositeEdges(img.Image base, img.Image edges) {
    final result = base.clone();
    const edgeThreshold = 80;

    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final edgePixel = edges.getPixel(x, y);
        final edgeValue = edgePixel.r;

        if (edgeValue > edgeThreshold) {
          // Darken the pixel for edges
          final basePixel = result.getPixel(x, y);
          final factor = 0.3; // Darken factor
          final newR = (basePixel.r * factor).round();
          final newG = (basePixel.g * factor).round();
          final newB = (basePixel.b * factor).round();

          result.setPixelRgba(x, y, newR, newG, newB, basePixel.a.toInt());
        }
      }
    }

    return result;
  }
}
