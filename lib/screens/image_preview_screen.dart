import 'package:flutter/material.dart';
import 'dart:io';

class ImagePreviewScreen extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;

  const ImagePreviewScreen({super.key, this.imageFile, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true, // Set it to false to prevent panning.
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: imageFile != null
              ? Image.file(imageFile!)
              : Image.network(
                  imageUrl ?? '',
                  errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.broken_image, color: Colors.white, size: 50),
                ),
        ),
      ),
    );
  }
}