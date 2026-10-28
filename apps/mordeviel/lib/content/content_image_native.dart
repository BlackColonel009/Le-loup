import 'dart:io';
import 'package:flutter/material.dart';
import 'pack_store.dart';
import 'pack_messages.dart';
import 'require_packs.dart';

class ContentImage extends StatefulWidget {
  const ContentImage(
    this.asset, {
    super.key,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.cacheWidth,
    this.filterQuality = FilterQuality.medium,
    this.excludeFromSemantics = true,
    this.autoDownload = false,
    this.fallbackAsset,
  });
  final String asset;
  final String? fallbackAsset;
  final BoxFit fit;
  final double? width, height;
  final int? cacheWidth;
  final FilterQuality filterQuality;
  final bool excludeFromSemantics, autoDownload;
  @override
  State<ContentImage> createState() => _ContentImageState();
}

class _ContentImageState extends State<ContentImage> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ContentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) _load();
  }

  Future<void> _load() async {
    try {
      await PackStore.instance.initialize();
      if (widget.autoDownload) {
        await PackStore.instance.ensureAsset(widget.asset);
      }
    } catch (_) {
      /* Placeholder remains usable offline. */
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: PackStore.instance,
    builder: (context, _) {
      final path = PackStore.instance.pathFor(widget.asset);
      Widget placeholder(
        BuildContext context,
        Object error,
        StackTrace? stack,
      ) => widget.fallbackAsset != null
          ? Image.asset(
              widget.fallbackAsset!,
              fit: widget.fit,
              width: widget.width,
              height: widget.height,
            )
          : Center(
              child: IconButton(
                tooltip: 'Image indisponible · Ouvrir les téléchargements',
                icon: const Icon(
                  Icons.download_for_offline_outlined,
                  color: Color(0xFFD5B47A),
                ),
                onPressed: downloadablePackForAsset(widget.asset) == null
                    ? null
                    : () => ensurePacksAvailable(
                        context,
                        [downloadablePackForAsset(widget.asset)!],
                        reason:
                            'Cette image nécessite un pack qui n’est pas installé sur cet appareil.',
                      ),
              ),
            );
      if (path != null) {
        return Image.file(
          File(path),
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          cacheWidth: widget.cacheWidth,
          filterQuality: widget.filterQuality,
          excludeFromSemantics: widget.excludeFromSemantics,
          errorBuilder: placeholder,
        );
      }
      if (widget.asset.contains('/stickers/') ||
          widget.asset.contains('/horror/')) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: placeholder(context, StateError('Pack absent'), null),
        );
      }
      return Image.asset(
        widget.asset,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        cacheWidth: widget.cacheWidth,
        filterQuality: widget.filterQuality,
        excludeFromSemantics: widget.excludeFromSemantics,
        errorBuilder: placeholder,
      );
    },
  );
}
