import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart'; // Add 'photo_view' to pubspec.yaml
import 'package:cached_network_image/cached_network_image.dart';

class GalleryViewScreen extends StatefulWidget {
  final List<dynamic> galleryItems; // Can be String (URL) or File
  final int initialIndex;

  const GalleryViewScreen({
    super.key, 
    required this.galleryItems, 
    this.initialIndex = 0
  });

  @override
  State<GalleryViewScreen> createState() => _GalleryViewScreenState();
}

class _GalleryViewScreenState extends State<GalleryViewScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(
          "${_pageController.hasClients ? _pageController.page!.round() + 1 : widget.initialIndex + 1} / ${widget.galleryItems.length}",
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        itemCount: widget.galleryItems.length,
        pageController: _pageController,
        onPageChanged: (index) => setState(() {}), // Update title counter
        builder: (context, index) {
          final item = widget.galleryItems[index];
          ImageProvider provider;

          if (item is File) {
            provider = FileImage(item);
          } else {
            provider = CachedNetworkImageProvider(item as String);
          }

          return PhotoViewGalleryPageOptions(
            imageProvider: provider,
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            heroAttributes: PhotoViewHeroAttributes(tag: index), // Optional Hero
          );
        },
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}