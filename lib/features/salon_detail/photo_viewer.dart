import '../../core/l10n/app_locale.dart';
import 'package:flutter/material.dart' hide Text;
import '../../core/l10n/app_text.dart';
import '../../core/widgets/avatars/avatar_image.dart';

/// Полноэкранный просмотр фото с листанием и зумом (галерея салона, портфолио мастера)
class PhotoViewer extends StatefulWidget {
  /// Ресурсы приложения (`assets/...`) или пути к файлам
  final List<String> photos;
  final int initialIndex;

  /// Подпись под фото с индексом (например, услуга, цена и кнопка записи у работы мастера)
  final Widget Function(BuildContext context, int index)? footerBuilder;

  const PhotoViewer({super.key, required this.photos, this.initialIndex = 0, this.footerBuilder});

  static Future<void> show(
    BuildContext context, {
    required List<String> photos,
    int initialIndex = 0,
    Widget Function(BuildContext context, int index)? footerBuilder,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => PhotoViewer(photos: photos, initialIndex: initialIndex, footerBuilder: footerBuilder),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image(
                  image: avatarProvider(widget.photos[i]),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
                ),
              ),
            ),
          ),
          if (widget.footerBuilder != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: widget.footerBuilder!(context, _index),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: tr('Закрыть'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    '${_index + 1} / ${widget.photos.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
