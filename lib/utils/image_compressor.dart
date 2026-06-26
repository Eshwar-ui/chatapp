import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;

/// Utility class to compress images before encoding to base64
class ImageCompressor {
  /// Compress image to fit within Firestore's 1MB limit
  /// Returns compressed bytes or null if compression fails
  static Future<Uint8List?> compressImage(
    File imageFile, {
    int maxWidth = 800,
    int maxHeight = 800,
    int quality = 70,
    int maxSizeBytes = 900000, // ~900KB to stay under 1MB limit
  }) async {
    try {
      // Read original image
      final originalBytes = await imageFile.readAsBytes();

      // If already small enough, return as is
      if (originalBytes.length <= maxSizeBytes) {
        return originalBytes;
      }

      // Decode image
      final codec = await ui.instantiateImageCodec(
        originalBytes,
        targetWidth: maxWidth,
        targetHeight: maxHeight,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Convert to PNG with compression
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      var compressedBytes = byteData.buffer.asUint8List();

      // If still too large, resize more aggressively
      // PNG doesn't compress well, so we need to resize more
      if (compressedBytes.length > maxSizeBytes) {
        int newWidth = (maxWidth * 0.7).round();
        int newHeight = (maxHeight * 0.7).round();

        final codec2 = await ui.instantiateImageCodec(
          originalBytes,
          targetWidth: newWidth,
          targetHeight: newHeight,
        );
        final frame2 = await codec2.getNextFrame();
        final image2 = frame2.image;

        final byteData2 = await image2.toByteData(
          format: ui.ImageByteFormat.png,
        );
        image2.dispose();

        if (byteData2 != null) {
          compressedBytes = byteData2.buffer.asUint8List();
        }
      }

      // If still too large, resize more aggressively
      if (compressedBytes.length > maxSizeBytes) {
        int newWidth = maxWidth ~/ 2;
        int newHeight = maxHeight ~/ 2;

        final codec3 = await ui.instantiateImageCodec(
          originalBytes,
          targetWidth: newWidth,
          targetHeight: newHeight,
        );
        final frame3 = await codec3.getNextFrame();
        final image3 = frame3.image;

        final byteData3 = await image3.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (byteData3 != null) {
          compressedBytes = byteData3.buffer.asUint8List();
        }
      }

      image.dispose();
      return compressedBytes;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }

  /// Compress image bytes (for images already in memory)
  static Future<Uint8List?> compressImageBytes(
    Uint8List imageBytes, {
    int maxWidth = 800,
    int maxHeight = 800,
    int quality = 70,
    int maxSizeBytes = 900000,
  }) async {
    try {
      // If already small enough, return as is
      if (imageBytes.length <= maxSizeBytes) {
        return imageBytes;
      }

      // Decode and compress
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: maxWidth,
        targetHeight: maxHeight,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      var compressedBytes = byteData.buffer.asUint8List();

      // Reduce size if needed
      int currentQuality = quality;
      while (compressedBytes.length > maxSizeBytes && currentQuality > 20) {
        currentQuality -= 10;

        final codec2 = await ui.instantiateImageCodec(
          imageBytes,
          targetWidth: (maxWidth * (currentQuality / 100)).round(),
          targetHeight: (maxHeight * (currentQuality / 100)).round(),
        );
        final frame2 = await codec2.getNextFrame();
        final image2 = frame2.image;

        final byteData2 = await image2.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (byteData2 == null) break;

        compressedBytes = byteData2.buffer.asUint8List();
        image2.dispose();
      }

      image.dispose();
      return compressedBytes;
    } catch (e) {
      debugPrint('Error compressing image bytes: $e');
      return null;
    }
  }
}
