import 'package:flutter/material.dart';

class ContentImage extends StatelessWidget {
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
  Widget build(BuildContext context) => Image.asset(
    fallbackAsset ?? asset,
    fit: fit,
    width: width,
    height: height,
    cacheWidth: cacheWidth,
    errorBuilder: (_, _, _) => const Icon(Icons.download_for_offline_outlined),
  );
}
