import 'package:flutter/material.dart';
import 'dart:io';


class BookFoundPage extends StatelessWidget {
  final File searchedImageFile;
  final String matchedImageUrl;
  final int index;
  final double score;

  const BookFoundPage({
    super.key,
    required this.searchedImageFile,
    required this.matchedImageUrl,
    required this.index,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kitap Bulundu"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // 🔹 BAŞLIKLAR (üstte, hizalı)
            Row(
              children: const [
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      "Aranılan Kitaplık",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                SizedBox(
                  width: 70,
                  child: Center(
                    child: Text(
                      "Eşleşen Kitap",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 🔹 GÖRSELLER
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📚 ARANILAN KİTAPLIK
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      searchedImageFile,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // 📕 EŞLEŞEN SPINE
                SizedBox(
                  width: 70,
                  height: 180, // 🔥 boyu burada kontrol ediyoruz
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      matchedImageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 📍 SONUÇ KARTI
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      "📍 ${index + 1}. sırada bulundu",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Benzerlik skoru: ${(score * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageCardFile({
    required String title,
    required File imageFile,
    required double aspectRatio, // 🔴 BU YENİ
  }) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              imageFile,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
  Widget _imageCardNetwork({
    required String title,
    required String imageUrl,
    required double aspectRatio, // 🔴 BU YENİ
  }) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, size: 40),
            ),
          ),
        ),
      ],
    );
  }


}
