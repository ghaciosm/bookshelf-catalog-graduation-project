import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';

class ManualCropPage extends StatefulWidget {
  final File imageFile;
  const ManualCropPage({super.key, required this.imageFile});

  @override
  State<ManualCropPage> createState() => _ManualCropPageState();
}

class _ManualCropPageState extends State<ManualCropPage> {
  final CropController _controller = CropController();
  Uint8List? imageData;

  @override
  void initState() {
    super.initState();
    imageData = widget.imageFile.readAsBytesSync();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fotoğrafı Kırp"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => _controller.crop(),
          )
        ],
      ),
      body: imageData == null
          ? const Center(child: CircularProgressIndicator())
          : Crop(
              controller: _controller,
              image: imageData!,
              interactive: true, // 🔥 PINCH + DRAG
              withCircleUi: false,
              onCropped: (Uint8List croppedData) async {
                final file = File(
                  '${widget.imageFile.parent.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
                );
                await file.writeAsBytes(croppedData);
                Navigator.pop(context, file);
              },
            ),
    );
  }
}
