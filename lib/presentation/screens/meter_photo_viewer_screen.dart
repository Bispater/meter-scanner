import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

/// Foto del medidor a pantalla completa: pellizco, pan y doble toque (photo_view).
class MeterPhotoViewerScreen extends StatelessWidget {
  final String imagePath;

  const MeterPhotoViewerScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PhotoView(
            imageProvider: FileImage(File(imagePath)),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4,
            initialScale: PhotoViewComputedScale.contained,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            loadingBuilder: (_, __) => const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white38, size: 64),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
