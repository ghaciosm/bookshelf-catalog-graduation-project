import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';
import 'update_shelf_page.dart';
import 'book_found_page.dart';
import 'dart:io';



class ShelfDetailPage extends StatefulWidget {
  final String shelfName;
  const ShelfDetailPage({super.key, required this.shelfName});

  @override
  State<ShelfDetailPage> createState() => _ShelfDetailPageState();
}

class _ShelfDetailPageState extends State<ShelfDetailPage> {
  List books = [];
  bool loading = true;

  late final String backend;
  late PageController pageController;


  @override
  void initState() {
    super.initState();
    pageController = PageController(viewportFraction: 0.90);
    backend =
        "http://${dotenv.env["BACKEND_IP"]}:${dotenv.env["BACKEND_PORT"]}";
    loadShelfBooks();
  }

  // -----------------------------
  // 📌 Kitaplık kitaplarını yükler
  // -----------------------------
  Future loadShelfBooks() async {
    setState(() => loading = true);

    final res = await http.get(
      Uri.parse("$backend/get_shelf/${widget.shelfName}"),
    );

    final data = jsonDecode(res.body);

    setState(() {
      books = data["books"];
      loading = false;
    });
  }

  // ===========================================================
  // 📌 Kamera mı Galeri mi? Menü
  // ===========================================================
  Future searchInNewPhoto(String bookId) async {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Kamera ile çek"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageAndSearch(bookId, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Galeriden seç"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageAndSearch(bookId, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================
  // 📌 Fotoğrafı al → backend’e gönder
  // ===========================================================
  Future _pickImageAndSearch(String bookId, ImageSource source) async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: source,
      imageQuality: 95,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (photo == null) return;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse("$backend/find_book"),
    );

    request.fields["book_id"] = bookId;

    final bytes = await photo.readAsBytes();
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

    if (data["found"] == true) {
      final match = data["match"];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookFoundPage(
            searchedImageFile: File(photo.path), // 🔥 KRİTİK
            matchedImageUrl:
                "$backend/preview/after/${match["after"]}",
            index: int.parse(
              match["after"].split("_")[1].split(".")[0],
            ),
            score: match["score"],
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text("Bulunamadı"),
          content: Text("Bu kitap yeni fotoğrafta tespit edilemedi."),
        ),
      );
    }
  }

  // ===========================================================
  // 🗑️ KİTABI SİL
  // ===========================================================
  Future deleteBook(String bookId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Kitabı Sil"),
        content: const Text(
            "Bu spine kalıcı olarak silinecek. Emin misin?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // await http.post(
    //   Uri.parse("$backend/delete_book"),
    //   body: {"book_id": bookId},
    // );
    await http.post(
      Uri.parse("$backend/delete_book"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"book_id": bookId}),
    );


    await loadShelfBooks();

    if (mounted) {
      imageCache.clear();
      imageCache.clearLiveImages();
      pageController.jumpToPage(0);
    }

  }

  // ===========================================================
  // 📌 ARAYÜZ
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.shelfName),
        actions: [
          IconButton(
            icon: const Icon(Icons.update),
            tooltip: "Kitaplığı Güncelle",
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      UpdateShelfPage(shelfName: widget.shelfName),
                ),
              );

              // 🔥 BURASI ASIL ÖNEMLİ YER
              if (updated == true) {
                loadShelfBooks(); // kitaplığı yeniden çek
              }
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : PageView.builder(
              itemCount: books.length,
              controller: pageController,
              itemBuilder: (context, index) {
                final book = books[index];

                final imgUrl =
                    "$backend/kitapliklar/${widget.shelfName}/${book['image']}";

                return Padding(
                  padding: const EdgeInsets.all(10),
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(
                              "$imgUrl?v=${DateTime.now().millisecondsSinceEpoch}",
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image, size: 80),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          book["id"],
                          style: const TextStyle(
                              fontSize: 18, color: Colors.grey),
                        ),

                        const SizedBox(height: 15),

                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                searchInNewPhoto(book["id"]),
                            icon: const Icon(Icons.search),
                            label: const Text("Yeni fotoğrafta ara"),
                            style: ElevatedButton.styleFrom(
                              minimumSize:
                                  const Size(double.infinity, 45),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton.icon(
                            onPressed: () => deleteBook(book["id"]),
                            icon: const Icon(Icons.delete),
                            label: const Text("Sil"),
                            style: ElevatedButton.styleFrom(
                              minimumSize:
                                  const Size(double.infinity, 45),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
