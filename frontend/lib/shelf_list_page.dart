import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'shelf_detail_page.dart';

class ShelfListPage extends StatefulWidget {
  const ShelfListPage({super.key});

  @override
  State<ShelfListPage> createState() => _ShelfListPageState();
}

class _ShelfListPageState extends State<ShelfListPage> {
  List<String> shelves = [];
  bool loading = true;

  late final String backend;
  late final String backendIp;
  late final String backendPort;

  @override
  void initState() {
    super.initState();

    backendIp = dotenv.env["BACKEND_IP"]!;
    backendPort = dotenv.env["BACKEND_PORT"]!;
    backend = "http://$backendIp:$backendPort";

    loadShelves();
  }

  Future loadShelves() async {
    try {
      var res = await http.get(Uri.parse("$backend/list_shelves"));
      var data = jsonDecode(res.body);

      setState(() {
        shelves = List<String>.from(data["shelves"]);
        loading = false;
      });
    } catch (e) {
      print("HATA: $e");
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kitaplıklar")),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: shelves.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.menu_book),
                    title: Text(
                      shelves[index],
                      style: const TextStyle(fontSize: 18),
                    ),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShelfDetailPage(
                            shelfName: shelves[index],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
