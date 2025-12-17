import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';

/// 自定义 ImageProvider，用于裁剪图片并保留中间部分
class CroppedImageProvider extends ImageProvider<CroppedImageProvider> {
  final ImageProvider imageProvider;
  final double targetAspectRatio;

  CroppedImageProvider({
    required this.imageProvider,
    required this.targetAspectRatio,
  });

  @override
  Future<CroppedImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CroppedImageProvider>(this);
  }

  @override
  ImageStreamCompleter load(CroppedImageProvider key,dynamic  decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAndCropImage(key, decode),
      scale: 1.0,
    );
  }

  Future<ui.Codec> _loadAndCropImage(CroppedImageProvider key, decode) async {
    // 加载原始图片
    final ImageStream stream = imageProvider.resolve(ImageConfiguration.empty);
    final Completer<ui.Image> completer = Completer<ui.Image>();
    late ImageStreamListener listener;

    listener = ImageStreamListener((ImageInfo imageInfo, bool synchronousCall) {
      completer.complete(imageInfo.image);
      stream.removeListener(listener);
    });

    stream.addListener(listener);

    final ui.Image originalImage = await completer.future;

    // 获取原始图片的宽高
    final int originalWidth = originalImage.width;
    final int originalHeight = originalImage.height;

    // 计算裁剪区域，保留中间部分
    final double originalAspectRatio = originalWidth / originalHeight;
    int cropWidth, cropHeight, cropX, cropY;

    if (originalAspectRatio > targetAspectRatio) {
      // 图片更宽，裁剪左右，保留中间部分
      cropHeight = originalHeight;
      cropWidth = (cropHeight * targetAspectRatio).toInt();
      cropX = ((originalWidth - cropWidth) / 2).toInt(); // 居中裁剪
      cropY = 0;
    } else {
      // 图片更高，裁剪上下，保留中间部分
      cropWidth = originalWidth;
      cropHeight = (cropWidth / targetAspectRatio).toInt();
      cropX = 0;
      cropY = ((originalHeight - cropHeight) / 2).toInt(); // 居中裁剪
    }

    // 裁剪图片
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Rect srcRect = Rect.fromLTWH(
      cropX.toDouble(),
      cropY.toDouble(),
      cropWidth.toDouble(),
      cropHeight.toDouble(),
    );
    final Rect dstRect = Rect.fromLTWH(0, 0, cropWidth.toDouble(), cropHeight.toDouble());
    canvas.drawImageRect(originalImage, srcRect, dstRect, Paint());
    final ui.Image croppedImage = await recorder.endRecording().toImage(cropWidth, cropHeight);

    // 编码裁剪后的图片
    final ByteData? byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List bytes = byteData!.buffer.asUint8List();
    return decode(Uint8List.fromList(bytes));
  }

  @override
  bool operator ==(Object other) {
    return other is CroppedImageProvider &&
        other.imageProvider == imageProvider &&
        other.targetAspectRatio == targetAspectRatio;
  }

  @override
  int get hashCode => Object.hash(imageProvider, targetAspectRatio);
}
