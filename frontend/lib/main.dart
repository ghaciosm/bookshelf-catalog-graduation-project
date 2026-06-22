import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'create_shelf_page.dart';
import 'shelf_detail_page.dart';
import 'update_shelf_page.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const KitaplikApp());
}

class KitaplikApp extends StatelessWidget {
  const KitaplikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> shelves = [];
  bool loadingShelves = true;

  late final String backend;

  @override
  void initState() {
    super.initState();
    final ip = dotenv.env['BACKEND_IP']!;
    final port = dotenv.env['BACKEND_PORT']!;
    backend = "http://$ip:$port";
    loadShelves();
  }

  Future loadShelves() async {
    try {
      final res = await http.get(Uri.parse("$backend/list_shelves"));
      final data = jsonDecode(res.body);

      setState(() {
        shelves = List<String>.from(data["shelves"]);
        loadingShelves = false;
      });
    } catch (e) {
      debugPrint("Hata: $e");
    }
  }

  Future deleteShelf(String name) async {
    await http.delete(Uri.parse("$backend/delete_shelf/$name"));
    loadShelves();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.menu_book, size: 22),
            SizedBox(width: 8),
            Text(
              "Kitaplık Katalog",
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateShelfPage(),
                  ),
                );
                loadShelves();
              },
              icon: const Icon(Icons.add_box),
              label: const Text("Kitaplık Oluştur"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 20),
            loadingShelves
                ? const CircularProgressIndicator()
                : Expanded(
                    child: ListView.builder(
                      itemCount: shelves.length,
                      itemBuilder: (context, index) {
                        final name = shelves[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.menu_book),
                            title: Text(name),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.update, color: Colors.blue),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => UpdateShelfPage(shelfName: name),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => deleteShelf(name),
                                ),
                              ],
                            ),

                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ShelfDetailPage(shelfName: name),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
