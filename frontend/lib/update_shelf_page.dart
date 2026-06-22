import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';

import 'manual_crop_page.dart';

class UpdateShelfPage extends StatefulWidget {
  final String shelfName;
  const UpdateShelfPage({super.key, required this.shelfName});

  @override
  State<UpdateShelfPage> createState() => _UpdateShelfPageState();
}

class _UpdateShelfPageState extends State<UpdateShelfPage> {
  bool loading = false;

  Map<String, dynamic>? result;
  File? previewImage;

  late final String backend;

  @override
  void initState() {
    super.initState();
    backend =
        "http://${dotenv.env['BACKEND_IP']}:${dotenv.env['BACKEND_PORT']}";
  }

  // ======================================================
  // 📸 Foto al → KIRP → BACKEND PREVIEW
  // ======================================================
  Future<void> pickAndPreview(ImageSource source) async {
    final picker = ImagePicker();

    final XFile? picked = await picker.pickImage(
      source: source,
      imageQuality: 95,
    );

    if (picked == null) return;

    final originalFile = File(picked.path);

    final File? croppedFile = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => ManualCropPage(imageFile: originalFile),
      ),
    );

    if (croppedFile == null) return;

    setState(() {
      previewImage = croppedFile;
      loading = true;
      result = null;
    });

    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$backend/update_shelf_preview"),
    );

    request.fields["shelf_name"] = widget.shelfName;

    final bytes = await croppedFile.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        "image",
        bytes,
        filename: "image.jpg",
        contentType: MediaType("image", "jpeg"),
      ),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final data = jsonDecode(body);

    setState(() {
      result = data;
      loading = false;
    });
  }

  // ======================================================
  // 🧱 UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Kitaplık Güncelle",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.shelfName,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => pickAndPreview(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Kamera"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => pickAndPreview(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Galeri"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (loading) const CircularProgressIndicator(),

            if (result != null) Expanded(child: buildResult()),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // 📊 SONUÇ EKRANI
  // ======================================================
  Widget buildResult() {
    final summary = result!["summary"];
    final added = result!["added_books"] ?? [];
    final removed = result!["removed_books"] ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // 🔥 YENİ: MEVCUT vs YENİ KARŞILAŞTIRMA
          buildCompareImages(
            oldImageUrl:
                "$backend/kitapliklar/${widget.shelfName}/raf_1.jpg",
            newImage: previewImage!,
          ),

          const SizedBox(height: 16),

          // 🔹 ÖZET
          buildSummaryCard(summary),

          const SizedBox(height: 16),

          if (added.isNotEmpty)
            buildExpandableSection(
              title: "➕ Eklenen Kitaplar",
              color: Colors.green,
              items: added,
            ),

          if (removed.isNotEmpty)
            buildExpandableSection(
              title: "➖ Eksilen Kitaplar",
              color: Colors.red,
              items: removed,
            ),

          const SizedBox(height: 24),

          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: applyUpdate,
            child: const Text("GÜNCELLE"),
          ),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("VAZGEÇ"),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // 🟦 ÖZET KARTI
  // ======================================================
  Widget buildSummaryCard(Map summary) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            summaryItem(Icons.add, Colors.green, summary["added"], "Eklenen"),
            summaryItem(
                Icons.remove, Colors.red, summary["removed"], "Eksilen"),
            summaryItem(Icons.check, Colors.grey, summary["matched"], "Aynı"),
          ],
        ),
      ),
    );
  }

  Widget summaryItem(
    IconData icon,
    Color color,
    int count,
    String label,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 6),
        Text(
          "$count",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label),
      ],
    );
  }

  // ======================================================
  // 📚 EKLENEN / EKSİLEN SPINE GRID
  // ======================================================
  Widget buildExpandableSection({
    required String title,
    required Color color,
    required List items,
  }) {
    return Card(
      child: ExpansionTile(
        title: Text(
          "$title (${items.length})",
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.35,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Column(
                children: [
                  Text("#${item["index"] + 1}",
                      style: const TextStyle(fontSize: 12)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        "$backend${item["image"]}",
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildCompareImages({
    required String oldImageUrl,
    required File newImage,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 🔹 MEVCUT
            Expanded(
              child: Column(
                children: [
                  const Text(
                    "Mevcut Kitaplık",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  AspectRatio(
                    aspectRatio: 3 / 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        oldImageUrl,
                        fit: BoxFit.contain, // 🔥 DEĞİŞTİ
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // 🔹 YENİ
            Expanded(
              child: Column(
                children: [
                  const Text(
                    "Yeni Fotoğraf",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  AspectRatio(
                    aspectRatio: 3 / 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        newImage,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ======================================================
  // ✅ APPLY
  // ======================================================
  Future<void> applyUpdate() async {
    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$backend/update_shelf_apply"),
    );

    request.fields["shelf_name"] = widget.shelfName;
    request.fields["image_path"] = result!["image_path"];

    await request.send();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kitaplık güncellendi ✅")),
      );
    }
  }
}
