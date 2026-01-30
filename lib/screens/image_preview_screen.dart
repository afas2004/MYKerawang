import 'package:flutter/material.dart';
import 'dart:io';
import 'package:photo_view/photo_view.dart'; // Ensure you have this package
import 'package:cached_network_image/cached_network_image.dart';

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
        child: imageFile != null
            ? Image.file(imageFile!)
            : PhotoView(
                // Use CachedNetworkImageProvider for better caching & error handling
                imageProvider: CachedNetworkImageProvider(imageUrl ?? ''),
                // This prevents the crash if the URL is 404 or broken
                errorBuilder: (context, error, stackTrace) {
                  return const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white, size: 50),
                      SizedBox(height: 10),
                      Text("Image unavailable", style: TextStyle(color: Colors.white)),
                    ],
                  );
                },
                // Optional: Show a spinner while loading full quality
                loadingBuilder: (context, event) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
      ),
    );
  }
}