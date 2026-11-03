import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';

class AmbientBlur extends StatefulWidget {
  final Future<Uint8List?> Function() captureFrame;
  final double sigmaX;
  final double sigmaY;
  final Duration duration;
  final double downscaleFactor;
  final double opacity;
  final Color vignetteColor;

  final double vignetteCornerRadius;
  final double vignetteFeather;
  final double vignetteMargin;

  const AmbientBlur({
    super.key,
    required this.captureFrame,
    this.sigmaX = 64.0,
    this.sigmaY = 64.0,
    this.duration = const Duration(seconds: 4),
    this.downscaleFactor = 4.0,
    this.opacity = 0.50,
    this.vignetteColor = Colors.black,
    this.vignetteCornerRadius = 64.0,
    this.vignetteFeather = 128,
    this.vignetteMargin = 0,
  });

  @override
  State<AmbientBlur> createState() => _AmbientBlurState();
}

class _AmbientBlurState extends State<AmbientBlur>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blendController;

  ui.Image? _oldImage;
  ui.Image? _currentImage;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _blendController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _blendController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _captureAndBlur(isFirst: false);
      }
    });

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _captureAndBlur(isFirst: true));
  }

  @override
  void didUpdateWidget(covariant AmbientBlur oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _blendController.duration = widget.duration;
      if (_blendController.isAnimating) {
        _blendController.forward(from: _blendController.value);
      }
    }
  }

  @override
  void dispose() {
    _blendController.dispose();
    if (_oldImage != _currentImage) _oldImage?.dispose();
    _currentImage?.dispose();
    super.dispose();
  }

  Future<void> _captureAndBlur({required bool isFirst}) async {
    if (!mounted || _isCapturing) return;
    _isCapturing = true;

    ui.Image? unblurredImage;
    ui.Image? blurredImage;
    ui.Codec? codec;
    ui.Picture? picture;

    try {
      final size = context.size;
      if (size == null || size.isEmpty) return;
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final renderScale = pixelRatio / widget.downscaleFactor;
      // Snapshot the decoded frame in mpv; Flutter cannot copy external GL textures.
      final bytes = await widget.captureFrame();
      if (!mounted) return;
      if (bytes == null) {
        _blendController.forward(from: 0.0);
        return;
      }
      codec = await ui.instantiateImageCodec(bytes,
          targetWidth: (size.width * renderScale).ceil());
      unblurredImage = (await codec.getNextFrame()).image;

      final scaledSigmaX =
          (widget.sigmaX * pixelRatio) / widget.downscaleFactor;
      final scaledSigmaY =
          (widget.sigmaY * pixelRatio) / widget.downscaleFactor;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: scaledSigmaX,
          sigmaY: scaledSigmaY,
          tileMode: ui.TileMode.clamp,
        );

      canvas.drawImage(unblurredImage, Offset.zero, paint);
      picture = recorder.endRecording();

      blurredImage = await picture.toImage(
        unblurredImage.width,
        unblurredImage.height,
      );

      if (!mounted) {
        blurredImage.dispose();
        return;
      }

      setState(() {
        final oldToDispose = _oldImage;

        if (isFirst) {
          _oldImage = blurredImage;
          _currentImage = blurredImage;
        } else {
          _oldImage = _currentImage;
          _currentImage = blurredImage;
        }

        if (oldToDispose != null &&
            oldToDispose != _oldImage &&
            oldToDispose != _currentImage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            oldToDispose.dispose();
          });
        }
      });

      _blendController.forward(from: 0.0);
    } catch (e) {
      debugPrint("AmbientBlur capture error: $e");
      blurredImage?.dispose();
      if (mounted && !_blendController.isAnimating) {
        _blendController.forward(from: 0.0);
      }
    } finally {
      picture?.dispose();
      codec?.dispose();
      unblurredImage?.dispose();
      if (mounted) _isCapturing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _currentImage != null;

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        if (isReady)
          Positioned.fill(
            child: Opacity(
              opacity: widget.opacity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_oldImage != null)
                    RawImage(
                      image: _oldImage,
                      fit: BoxFit.fill,
                    ),
                  if (_currentImage != null && _oldImage != _currentImage)
                    FadeTransition(
                      opacity: _blendController,
                      child: RawImage(
                        image: _currentImage,
                        fit: BoxFit.fill,
                      ),
                    ),
                  if (widget.vignetteColor.a > 0)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _RoundedRectVignettePainter(
                            color: widget.vignetteColor.withAlpha(125),
                            cornerRadius: widget.vignetteCornerRadius,
                            feather: widget.vignetteFeather,
                            margin: widget.vignetteMargin,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RoundedRectVignettePainter extends CustomPainter {
  final Color color;
  final double cornerRadius;
  final double feather;
  final double margin;

  _RoundedRectVignettePainter({
    required this.color,
    required this.cornerRadius,
    required this.feather,
    required this.margin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (feather > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, feather);
    }

    final insetRect = Rect.fromLTWH(
      margin + feather,
      margin + feather,
      size.width - 2 * (margin + feather),
      size.height - 2 * (margin + feather),
    );

    if (insetRect.width > 0 && insetRect.height > 0) {
      final safeRRect = RRect.fromRectAndRadius(
        insetRect,
        Radius.circular(cornerRadius),
      );

      final outerRect =
          Rect.fromLTWH(0, 0, size.width, size.height).inflate(feather * 3);
      final outerRRect = RRect.fromRectAndRadius(outerRect, Radius.zero);

      canvas.drawDRRect(outerRRect, safeRRect, paint);
    } else {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RoundedRectVignettePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.feather != feather ||
        oldDelegate.margin != margin;
  }
}
