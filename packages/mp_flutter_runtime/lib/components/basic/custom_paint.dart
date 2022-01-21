part of '../../mp_flutter_runtime.dart';

class _DrawableStore {
  final MPEngine engine;
  final decodedDrawables = <int, ui.Image>{};

  _DrawableStore({required this.engine});

  void decodeDrawable(Map params) {
    String? type = params['type'];
    if (type == 'networkImage') {
      decodeNetworkImage(params);
    } else if (type == 'memoryImage') {
      decodeMemoryImage(params);
    }
  }

  void decodeNetworkImage(Map params) async {
    int? target = params['target'];
    String? url = params['url'];
    if (target == null || url == null) return;
    try {
      final file = await DefaultCacheManager().getSingleFile(url);
      final image = await decodeImageFromList(file.readAsBytesSync());
      decodedDrawables[target] = image;
      _onDecodedResult(target, image.width, image.height);
    } catch (e) {
      _onDecodedError(target, e.toString());
    }
  }

  void decodeMemoryImage(Map params) async {
    int? target = params['target'];
    String? data = params['data'];
    if (target == null || data == null) return;
    try {
      final image = await decodeImageFromList(base64.decode(data));
      decodedDrawables[target] = image;
      _onDecodedResult(target, image.width, image.height);
    } catch (e) {
      _onDecodedError(target, e.toString());
    }
  }

  void _onDecodedResult(int target, int width, int height) {
    engine._sendMessage({
      "type": "decode_drawable",
      "message": {
        "event": "onDecode",
        "target": target,
        "width": width,
        "height": height,
      },
    });
  }

  void _onDecodedError(int target, String error) {
    engine._sendMessage({
      "type": "decode_drawable",
      "message": {
        "event": "onError",
        "target": target,
        "error": error,
      },
    });
  }
}

// ignore: must_be_immutable
class _CustomPaint extends ComponentView {
  static void _didReceivedCustomPaintMessage(
      Map message, MPEngine engine) async {
    String? event = message['event'];
    if (event == 'fetchImage') {
      int? target = message['target'];
      if (target != null) {
        ComponentView? targetView =
            engine._componentFactory._cacheViews[target]?.widget;
        if (targetView is _CustomPaint && targetView.context != null) {
          String base64EncodedData =
              await targetView._fetchEncodedImage(targetView.context!);
          engine._sendMessage({
            "type": "custom_paint",
            "message": {
              "event": "onFetchImageResult",
              "seqId": message["seqId"],
              "data": base64EncodedData,
            },
          });
        }
      }
    }
  }

  BuildContext? context;

  _CustomPaint({
    Key? key,
    Map? data,
    Map? parentData,
    required _MPComponentFactory componentFactory,
  }) : super(
            key: key,
            data: data,
            parentData: parentData,
            componentFactory: componentFactory);

  Future<String> _fetchEncodedImage(BuildContext context) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final canvasSize = getSize();
    _CustomPainter(
      commands: getValueFromAttributes(context, 'commands'),
      drawableStore: componentFactory.engine._drawableStore,
    ).paint(canvas, canvasSize);
    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(
      canvasSize.width.toInt(),
      canvasSize.height.toInt(),
    );
    final imgData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (imgData == null) {
      return '';
    }
    return base64.encode(imgData.buffer.asUint8List());
  }

  @override
  Widget builder(BuildContext context) {
    this.context = context;
    return CustomPaint(
      size: getSize(),
      painter: _CustomPainter(
        commands: getValueFromAttributes(context, 'commands'),
        drawableStore: componentFactory.engine._drawableStore,
      ),
    );
  }
}

class _CustomPainter extends CustomPainter {
  final List? commands;
  final _DrawableStore drawableStore;
  final sharedPaint = Paint();

  _CustomPainter({
    this.commands,
    required this.drawableStore,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (commands == null) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    int idx = -1;
    for (final command in commands!) {
      idx++;
      if (command is Map) {
        String? action = command['action'];
        if (action == null) continue;
        if (idx == 0 && action == 'drawColor') continue;
        switch (action) {
          case 'drawRect':
            resetPaint(command['paint']);
            canvas.drawRect(
                Rect.fromLTWH(
                  doubleFromMap(command, 'x'),
                  doubleFromMap(command, 'y'),
                  doubleFromMap(command, 'width'),
                  doubleFromMap(command, 'height'),
                ),
                sharedPaint);
            break;
          case 'drawDRRect':
            resetPaint(command['paint']);
            final outer = pathFromData(command['outer']);
            final inner = pathFromData(command['inner']);
            outer.addPath(inner, const Offset(0, 0));
            outer.fillType = PathFillType.evenOdd;
            canvas.drawPath(outer, sharedPaint);
            break;
          case 'drawPath':
            resetPaint(command['paint']);
            canvas.drawPath(pathFromData(command['path']), sharedPaint);
            break;
          case 'clipPath':
            canvas.clipPath(pathFromData(command['path']));
            break;
          case 'drawColor':
            canvas.drawColor(
              Color(int.tryParse(command['color'] ?? '0') ?? 0),
              (() {
                switch (command['blendMode']) {
                  case 'BlendMode.clear':
                    return BlendMode.clear;
                  default:
                    return BlendMode.color;
                }
              })(),
            );
            break;
          case 'drawImage':
            final drawable = command['drawable'];
            if (drawable is! int) continue;
            final image = drawableStore.decodedDrawables[drawable];
            if (image != null) {
              resetPaint(command['paint']);
              canvas.drawImage(
                image,
                Offset(
                    doubleFromMap(command, 'dx'), doubleFromMap(command, 'dy')),
                sharedPaint,
              );
            }
            break;
          case 'drawImageRect':
            final drawable = command['drawable'];
            if (drawable is! int) continue;
            final image = drawableStore.decodedDrawables[drawable];
            if (image != null) {
              resetPaint(command['paint']);
              canvas.drawImageRect(
                image,
                Rect.fromLTWH(
                    doubleFromMap(command, 'srcX'),
                    doubleFromMap(command, 'srcY'),
                    doubleFromMap(command, 'srcW'),
                    doubleFromMap(command, 'srcH')),
                Rect.fromLTWH(
                    doubleFromMap(command, 'dstX'),
                    doubleFromMap(command, 'dstY'),
                    doubleFromMap(command, 'dstW'),
                    doubleFromMap(command, 'dstH')),
                sharedPaint,
              );
            }
            break;
          case 'save':
            canvas.save();
            break;
          case 'restore':
            canvas.restore();
            break;
          case 'rotate':
            canvas.rotate(doubleFromMap(command, 'radians'));
            break;
          case 'scale':
            canvas.scale(
                doubleFromMap(command, 'sx'), doubleFromMap(command, 'sy'));
            break;
          case 'translate':
            canvas.translate(
                doubleFromMap(command, 'dx'), doubleFromMap(command, 'dy'));
            break;
          case 'transform':
            final float64List = Float64List.fromList([
              doubleFromMap(command, 'a'),
              doubleFromMap(command, 'b'),
              0,
              0,
              doubleFromMap(command, 'c'),
              doubleFromMap(command, 'd'),
              0,
              0,
              0,
              0,
              1,
              0,
              doubleFromMap(command, 'tx'),
              doubleFromMap(command, 'ty'),
              0,
              1,
            ]);
            canvas.transform(float64List);
            break;
          case 'skew':
            canvas.skew(
                doubleFromMap(command, 'sx'), doubleFromMap(command, 'sy'));
            break;
          default:
        }
      }
    }
    canvas.restore();
  }

  double doubleFromMap(Map map, String theKey) {
    final v = map[theKey];
    if (v is num) {
      return v.toDouble();
    }
    return 0.0;
  }

  Path pathFromData(Map? map) {
    final p = Path();
    final commands = map?['commands'];
    if (commands is List) {
      for (final command in commands) {
        if (command is! Map) continue;
        String action = command['action'];
        switch (action) {
          case 'moveTo':
            p.moveTo(doubleFromMap(command, 'x'), doubleFromMap(command, 'y'));
            break;
          case 'lineTo':
            p.lineTo(doubleFromMap(command, 'x'), doubleFromMap(command, 'y'));
            break;
          case 'quadraticBezierTo':
            p.quadraticBezierTo(
                doubleFromMap(command, 'x1'),
                doubleFromMap(command, 'y1'),
                doubleFromMap(command, 'x2'),
                doubleFromMap(command, 'y2'));
            break;
          case 'cubicTo':
            p.cubicTo(
                doubleFromMap(command, 'x1'),
                doubleFromMap(command, 'y1'),
                doubleFromMap(command, 'x2'),
                doubleFromMap(command, 'y2'),
                doubleFromMap(command, 'x3'),
                doubleFromMap(command, 'y3'));
            break;
          case 'arcTo':
            p.arcTo(
              Rect.fromCenter(
                center: Offset(
                  doubleFromMap(command, 'x'),
                  doubleFromMap(command, 'y'),
                ),
                width: doubleFromMap(command, 'width'),
                height: doubleFromMap(command, 'height'),
              ),
              doubleFromMap(command, 'startAngle'),
              doubleFromMap(command, 'sweepAngle'),
              true,
            );
            break;
          case 'arcToPoint':
            p.arcToPoint(
              Offset(
                doubleFromMap(command, 'arcEndX'),
                doubleFromMap(command, 'arcEndY'),
              ),
              radius: Radius.circular(doubleFromMap(command, 'radiusX')),
              rotation: doubleFromMap(command, 'rotation'),
              largeArc: command['largeArc'] == true,
              clockwise: command['clockwise'] == true,
            );
            break;
          case 'close':
            p.close();
            break;
          default:
        }
      }
    }
    return p;
  }

  void resetPaint(Map? paintData) {
    paintData ??= {};
    sharedPaint.strokeWidth = doubleFromMap(paintData, 'strokeWidth');
    sharedPaint.strokeMiterLimit = doubleFromMap(paintData, 'miterLimit');
    sharedPaint.strokeCap = (() {
      switch (paintData!['strokeCap']) {
        case 'StrokeCap.butt':
          return StrokeCap.butt;
        case 'StrokeCap.round':
          return StrokeCap.round;
        case 'StrokeCap.square':
          return StrokeCap.square;
        default:
          return StrokeCap.butt;
      }
    })();
    sharedPaint.strokeJoin = (() {
      switch (paintData!['strokeJoin']) {
        case 'StrokeJoin.miter':
          return StrokeJoin.miter;
        case 'StrokeJoin.round':
          return StrokeJoin.round;
        case 'StrokeJoin.bevel':
          return StrokeJoin.bevel;
        default:
          return StrokeJoin.miter;
      }
    })();
    sharedPaint.style = paintData['style'] == 'PaintingStyle.fill'
        ? PaintingStyle.fill
        : PaintingStyle.stroke;
    sharedPaint.color = Color(int.tryParse(paintData['color'] ?? '0') ?? 0);
    final alpha =
        paintData['alpha'] != null ? doubleFromMap(paintData, 'alpha') : 1.0;
    if (alpha < 1.0) {
      sharedPaint.color = sharedPaint.color.withOpacity(alpha);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
