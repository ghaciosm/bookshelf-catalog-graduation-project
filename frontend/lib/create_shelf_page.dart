import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';

import 'shelf_list_page.dart';
import 'manual_crop_page.dart'; // 👈 ÖNEMLİ

class CreateShelfPage extends StatefulWidget {
  const CreateShelfPage({super.key});

  @override
  State<CreateShelfPage> createState() => _CreateShelfPageState();
}

class _CreateShelfPageState extends State<CreateShelfPage> {
  final TextEditingController nameController = TextEditingController();
  final ImagePicker picker = ImagePicker();

  List<File> rafImages = [];

  late final String backend;

  @override
  void initState() {
    super.initState();
    final ip = dotenv.env['BACKEND_IP']!;
    final port = dotenv.env['BACKEND_PORT']!;
    backend = "http://$ip:$port";
  }

  // ======================================================
  // 📸 Galeriden seç → MANUEL KIRP → EKLE
  // ======================================================
  Future<void> pickRafImage() async {
    final List<XFile>? images = await picker.pickMultiImage(
      imageQuality: 95,
      maxWidth: 2048,
    );

    if (images == null || images.isEmpty) return;

    for (final img in images) {
      final File original = File(img.path);

      // 👉 KIRPMA EKRANI AÇ
      final File? cropped = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          builder: (_) => ManualCropPage(imageFile: original),
        ),
      );

      if (cropped != null) {
        setState(() {
          rafImages.add(cropped);
        });
      }
    }
  }

  // ======================================================
  // 📡 Sunucuya gönder
  // ======================================================
  Future<void> sendShelfToServer() async {
    if (nameController.text.isEmpty || rafImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kitaplık adı ve en az 1 raf fotoğrafı gerekli"),
        ),
      );
      return;
    }

    final request =
        http.MultipartRequest("POST", Uri.parse("$backend/create_shelf"));
    request.fields["shelf_name"] = nameController.text;

    // for (final img in rafImages) {
    //   request.files.add(
    //     await http.MultipartFile.fromPath(
    //       "raf_fotograflari",
    //       img.path,
    //     ),
    //   );
    // }
    for (final img in rafImages) {
    final bytes = await img.readAsBytes();

      request.files.add(
        http.MultipartFile.fromBytes(
          "raf_fotograflari",
          bytes,
          filename: "raf.jpg",
          contentType: MediaType("image", "jpeg"),
        ),
      );
    }


    await request.send();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ShelfListPage()),
    );
  }

  // ======================================================
  // 🧱 UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kitaplık Oluştur")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            const SizedBox(height: 12),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Kitaplık adı",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: pickRafImage,
              icon: const Icon(Icons.photo_library),
              label: const Text("Raf Fotoğrafı Seç"),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: rafImages.isEmpty
                  ? const Center(
                      child: Text("Henüz raf fotoğrafı eklenmedi"),
                    )
                  : ListView.builder(
                      itemCount: rafImages.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Image.file(
                          rafImages[i],
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
            ),

            ElevatedButton.icon(
              onPressed: sendShelfToServer,
              icon: const Icon(Icons.save),
              label: const Text("Kitaplığı Kaydet"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
