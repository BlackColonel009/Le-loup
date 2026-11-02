import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// A small square upload, with no original EXIF or local file path attached.
Future<Uint8List> prepareProfilePhoto(Uint8List source) async {
  if (source.length > 8 * 1048576) {
    throw const FormatException('Choisis une photo de moins de 8 Mo.');
  }
  final codec = await ui.instantiateImageCodec(
    source,
    targetWidth: 768,
    allowUpscaling: false,
  );
  ui.Image? image, square;
  ui.Picture? picture;
  try {
    image = (await codec.getNextFrame()).image;
    final edge = math.min(image.width, image.height).toDouble();
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawImageRect(
      image,
      ui.Rect.fromCenter(
        center: ui.Offset(image.width / 2, image.height / 2),
        width: edge,
        height: edge,
      ),
      const ui.Rect.fromLTWH(0, 0, 384, 384),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    picture = recorder.endRecording();
    square = await picture.toImage(384, 384);
    final bytes = await square.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null || bytes.lengthInBytes > 600000) {
      throw const FormatException(
        'Cette photo ne peut pas être préparée. Choisis-en une autre.',
      );
    }
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    image?.dispose();
    square?.dispose();
    picture?.dispose();
    codec.dispose();
  }
}
