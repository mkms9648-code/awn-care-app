import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/chat_service.dart';

/// Thumbnail for a Storage-backed attachment — fetches a signed URL lazily,
/// and opens a full-screen pinch-to-zoom viewer on tap.
class ZoomableAttachmentImage extends StatefulWidget {
  const ZoomableAttachmentImage({super.key, required this.storagePath, this.size = 100});

  final String storagePath;
  final double size;

  @override
  State<ZoomableAttachmentImage> createState() => _ZoomableAttachmentImageState();
}

class _ZoomableAttachmentImageState extends State<ZoomableAttachmentImage> {
  late Future<String?> _urlFuture;

  @override
  void initState() {
    super.initState();
    _urlFuture = context.read<ChatService>().getSignedUrl(widget.storagePath);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _urlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _box(child: const CircularProgressIndicator(strokeWidth: 2));
        }
        final url = snapshot.data;
        if (url == null) {
          return _box(child: const Icon(Icons.broken_image_outlined, color: Colors.grey));
        }
        return GestureDetector(
          onTap: () => _openFullScreen(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _box(child: const Icon(Icons.broken_image_outlined)),
            ),
          ),
        );
      },
    );
  }

  Widget _box({required Widget child}) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
      child: Center(child: child),
    );
  }

  void _openFullScreen(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Image.network(url),
            ),
          ),
        ),
      ),
    );
  }
}
