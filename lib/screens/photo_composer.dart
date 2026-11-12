part of '../main.dart';

Widget _editorLabel(String s) => Text(
      s.toUpperCase(),
      style: const TextStyle(
        color: secondary,
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 1.2,
      ),
    );

// ==========================================
// ФИЛЬТРЫ (ЦВЕТОВЫЕ МАТРИЦЫ)
// ==========================================
const _filterOriginal = <double>[
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];
const _filterWarm = <double>[
  1.15, 0.05, 0, 0, 10,
  0.02, 1.02, 0, 0, 0,
  0, 0, 0.88, 0, -5,
  0, 0, 0, 1, 0,
];
const _filterCold = <double>[
  0.9, 0, 0.05, 0, -5,
  0, 1.0, 0.05, 0, 0,
  0, 0.02, 1.15, 0, 10,
  0, 0, 0, 1, 0,
];
const _filterMono = <double>[
  0.299, 0.587, 0.114, 0, 0,
  0.299, 0.587, 0.114, 0, 0,
  0.299, 0.587, 0.114, 0, 0,
  0, 0, 0, 1, 0,
];
const _filterVintage = <double>[
  0.9, 0.2, 0.05, 0, 10,
  0.1, 0.85, 0.1, 0, 5,
  0.05, 0.1, 0.75, 0, 0,
  0, 0, 0, 1, 0,
];

List<double> _lerpMatrix(List<double> a, List<double> b, double t) =>
    List<double>.generate(a.length, (i) => a[i] + (b[i] - a[i]) * t);

List<double> _matrixFor(String filter, double intensity) {
  final base = switch (filter) {
    'Тёплый' => _filterWarm,
    'Холодный' => _filterCold,
    'Ч/Б' => _filterMono,
    'Винтаж' => _filterVintage,
    _ => _filterOriginal,
  };
  return _lerpMatrix(_filterOriginal, base, intensity.clamp(0.0, 1.0));
}

// ==========================================
// РЕДАКТОР
// ==========================================

class PhotoComposer extends StatefulWidget {
  final Store store;
  const PhotoComposer({super.key, required this.store});
  @override
  State<PhotoComposer> createState() => _PhotoComposerState();
}

class _PhotoComposerState extends State<PhotoComposer>
    with SingleTickerProviderStateMixin {
  late _Composition demo;
  String tool = 'Макеты';
  final _textController = TextEditingController();
  bool _panelOpen = false, _saving = false, _comparing = false;
  final List<String> _history = [], _future = [];
  final GlobalKey _canvasKey = GlobalKey();
  String? _activePhotoId;

  // --- ЛОГИКА ВСТРЯХИВАНИЯ ---
  static const _shakeChannel = MethodChannel('by.picpac.demo/shake');
  late final AnimationController _shuffleAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  Map<Layer, (double, double, double, double)>? _shuffleFrom, _shuffleTo;

  String _state() => jsonEncode(demo.toMap());

  void _checkpoint() {
    _finishShuffle();
    final state = _state();
    if (_history.isEmpty || _history.last != state) _history.add(state);
    if (_history.length > 40) _history.removeAt(0);
    _future.clear();
  }

  void _undo() {
    if (_history.isEmpty) return;
    _cancelShuffle();
    final state = _history.removeLast();
    _future.add(_state());
    setState(() => demo = _Composition.fromMap(
        Map<String, dynamic>.from(jsonDecode(state) as Map),
        widget.store.photos));
  }

  void _redo() {
    if (_future.isEmpty) return;
    _cancelShuffle();
    final state = _future.removeLast();
    _history.add(_state());
    setState(() => demo = _Composition.fromMap(
        Map<String, dynamic>.from(jsonDecode(state) as Map),
        widget.store.photos));
  }

  Future<void> _save() async {
    if (_saving) return;
    _finishShuffle();
    final wasComparing = _comparing;
    setState(() {
      _saving = true;
      _comparing = false;
    });
    try {
      if (wasComparing) await WidgetsBinding.instance.endOfFrame;
      final data = demo.toMap();
      final directory = widget.store.photoDirectory;
      if (directory != null) {
        final boundary = _canvasKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null) throw StateError('canvas unavailable');
        final snapshot = await boundary.toImage(pixelRatio: 2);
        try {
          final bytes = await snapshot.toByteData(format: ui.ImageByteFormat.png);
          if (bytes == null) throw StateError('image encoding failed');
          final filename =
              'composition-${DateTime.now().microsecondsSinceEpoch}.png';
          await File('$directory/$filename').writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
            flush: true,
          );
          data['preview'] = filename;
        } finally {
          snapshot.dispose();
        }
      }
      widget.store.composition = data;
      widget.store.changed();
      await widget.store.flush();
      if (widget.store.saveFailed) throw StateError('save failed');
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) message(context, 'Не удалось сохранить результат. Попробуйте ещё раз.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static const _tools = [
    ('ИИ', Icons.auto_awesome),
    ('Макеты', Icons.dashboard_outlined),
    ('Оверлеи', Icons.filter_frames_outlined),
    ('Эффекты', Icons.auto_awesome_outlined),
    ('Обрезка', Icons.crop),
  ];

  @override
  void initState() {
    super.initState();
    demo = _Composition.fromMap(widget.store.composition, widget.store.photos);
    if (widget.store.composition == null) demo.resetEditorLayers();
    _shuffleAnim.addListener(_onShuffleTick);
    _startShakeListening();
  }

  @override
  void dispose() {
    _shakeChannel.setMethodCallHandler(null);
    unawaited(_shakeChannel.invokeMethod<void>('stop').catchError((_) {}));
    _shuffleAnim.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _startShakeListening() async {
    _shakeChannel.setMethodCallHandler((call) async {
      if (call.method == 'shake' && mounted && !_saving) _shuffleCollage();
    });
    try {
      await _shakeChannel.invokeMethod<void>('start');
    } catch (_) {
      // Нет датчика или платформы — остаётся кнопка.
    }
  }

  void _onShuffleTick() {
    final from = _shuffleFrom, to = _shuffleTo;
    if (from == null || to == null) return;
    final t = _shuffleAnim.value;
    final move = Curves.easeOutBack.transform(t);
    final calm = Curves.easeOutCubic.transform(t);
    setState(() {
      to.forEach((layer, end) {
        final start = from[layer];
        if (start == null) return;
        layer.x = start.$1 + (end.$1 - start.$1) * move;
        layer.y = start.$2 + (end.$2 - start.$2) * move;
        layer.scale = start.$3 + (end.$3 - start.$3) * calm;
        layer.rotation = start.$4 + (end.$4 - start.$4) * move;
      });
    });
    if (_shuffleAnim.isCompleted) _finishShuffle();
  }

  void _finishShuffle() {
    final to = _shuffleTo;
    _shuffleFrom = null;
    _shuffleTo = null;
    if (to == null) return;
    _shuffleAnim.stop();
    to.forEach((layer, end) {
      layer.x = end.$1;
      layer.y = end.$2;
      layer.scale = end.$3;
      layer.rotation = end.$4;
    });
  }

  void _cancelShuffle() {
    _shuffleAnim.stop();
    _shuffleFrom = null;
    _shuffleTo = null;
  }

  void _shuffleCollage() {
    if (_saving) return;
    final photos = demo.layers.where((l) => l.type == 'photo').toList();
    if (photos.length < 2) {
      message(context, 'Добавьте хотя бы два фото, чтобы собрать коллаж');
      return;
    }
    _checkpoint();
    HapticFeedback.mediumImpact();
    final rnd = math.Random();
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(250, 250);
    
    // Перемешиваем фото
    photos.shuffle(rnd);
    final count = math.min(photos.length, 2 + rnd.nextInt(3));
    final from = <Layer, (double, double, double, double)>{
      for (final l in demo.layers) l: (l.x, l.y, l.scale, l.rotation),
    };
    final to = <Layer, (double, double, double, double)>{};
    
    // Случайные позиции и углы
    final spots = [
      (-.2, -.2),
      (.2, -.16),
      (-.16, .2),
      (.2, .2),
    ]..shuffle(rnd);
    
    for (var i = 0; i < count; i++) {
      final jitterX = (rnd.nextDouble() - .5) * .08 * size.width;
      final jitterY = (rnd.nextDouble() - .5) * .08 * size.height;
      to[photos[i]] = (
        spots[i].$1 * size.width + jitterX,
        spots[i].$2 * size.height + jitterY,
        .52 + rnd.nextDouble() * .16,
        (rnd.nextDouble() - .5) * .5,
      );
    }
    
    for (var i = 0; i < photos.length; i++) {
      photos[i].visible = i < count;
      if (i >= count) {
        photos[i]
          ..x = 0
          ..y = 0
          ..scale = 1
          ..rotation = 0;
      }
    }
    
    demo.activeFrame = 'Без рамки';
    demo.layers
      ..clear()
      ..addAll(photos);
    demo.activeLayer = count - 1;
    
    final animate = !MediaQuery.disableAnimationsOf(context);
    setState(() {
      _panelOpen = false;
      if (animate) {
        _shuffleFrom = from;
        _shuffleTo = to;
        for (final l in to.keys) {
          final f = from[l]!;
          l.x = f.$1;
          l.y = f.$2;
          l.scale = f.$3;
          l.rotation = f.$4;
        }
      } else {
        to.forEach((l, e) {
          l.x = e.$1;
          l.y = e.$2;
          l.scale = e.$3;
          l.rotation = e.$4;
        });
      }
    });
    if (animate) _shuffleAnim.forward(from: 0);
  }

  void _constrain(Layer layer) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    var size = box?.size ?? const Size(250, 250);
    final limitX = (size.width * (1 + layer.scale) / 2 - 24).clamp(24.0, 10000.0);
    final limitY = (size.height * (1 + layer.scale) / 2 - 24).clamp(24.0, 10000.0);
    layer.x = layer.x.clamp(-limitX, limitX);
    layer.y = layer.y.clamp(-limitY, limitY);
  }

  void _pickTool(String t) {
    setState(() {
      if (tool == t && _panelOpen) {
        _panelOpen = false;
      } else {
        tool = t;
        _panelOpen = true;
      }
    });
  }

  Future<void> _openAiForLayer() async {
    if (_activePhotoId == null) {
      message(context, 'Нажмите на фото, чтобы выбрать его для ИИ.');
      return;
    }
    final matches = widget.store.photos.where((p) => p.id == _activePhotoId).toList();
    if (matches.isEmpty) return;
    
    final ids = widget.store.photos.map((p) => p.id).toSet();
    final applied = await open<bool>(context, AiEditor(store: widget.store, photo: matches.first));
    if (!mounted || applied != true) return;
    
    final added = widget.store.photos.where((p) => !ids.contains(p.id)).toList();
    if (added.isNotEmpty) {
      _checkpoint();
      setState(() {
        final photo = added.last;
        demo.selected.add(photo.id);
        demo.layers.add(Layer(id: 'photo-ai-${photo.id}', imageId: photo.id));
        _activePhotoId = photo.id;
      });
      message(context, 'Копия добавлена.');
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: const Color(0xfffdfdfa),
        appBar: AppBar(
          title: const Text('Редактор фото'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(c),
          ),
          actions: [
            IconButton(onPressed: _history.isEmpty ? null : _undo, icon: const Icon(Icons.undo)),
            IconButton(onPressed: _future.isEmpty ? null : _redo, icon: const Icon(Icons.redo)),
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Сохраняем…' : 'Сохранить'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _iconRail(),
                    const VerticalDivider(width: 1, color: border),
                    Expanded(
                      child: Stack(
                        children: [
                          _canvas(c),
                          // Кнопка "Потрясти"
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Material(
                              color: Colors.white.withValues(alpha: .9),
                              borderRadius: BorderRadius.circular(20),
                              elevation: 4,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _shuffleCollage,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.vibration, size: 16, color: ink),
                                      SizedBox(width: 6),
                                      Text('Потрясти', style: TextStyle(fontSize: 12, color: ink, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_panelOpen)
                            Positioned(
                              left: 0, right: 0, top: 0, bottom: 0,
                              child: _toolPanel(c),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: border),
              _bottomBar(c),
            ],
          ),
        ),
      );

  Widget _photo(String id, {bool original = false}) {
    final matches = widget.store.photos.where((p) => p.id == id);
    if (matches.isEmpty) return const ColoredBox(color: peach, child: Icon(Icons.broken_image_outlined));
    final p = matches.first;
    final photo = original ? p.copyWith(turns: 0, crop: 'original', positionX: 0, positionY: 0, brightness: 0, frame: 'none', effect: 'none') : p;
    return PhotoPreview(store: widget.store, photo: photo);
  }

  Widget _iconRail() => Container(
        width: 64,
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          children: _tools.map((it) {
            final active = tool == it.$1;
            return InkWell(
              onTap: () => it.$1 == 'ИИ' ? _openAiForLayer() : _pickTool(it.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: active ? const Color(0xffe9ecdf) : Colors.transparent,
                child: Column(
                  children: [
                    Icon(it.$2, size: 22, color: active ? ink : secondary),
                    const SizedBox(height: 4),
                    Text(it.$1, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: active ? ink : secondary, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );

  Widget _toolPanel(BuildContext c) => Align(
        alignment: Alignment.topLeft,
        child: Container(
          width: 220,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: switch (tool) {
                'Макеты' => _choicePanel('макеты', ['Без рамки', 'Классика', 'Полароид', 'Два кадра', 'Три кадра', 'Коллаж 2×2', 'Плёнка'], demo.activeFrame, (v) {
                  _checkpoint();
                  setState(() => demo.activeFrame = v);
                }),
                'Оверлеи' => _choicePanel('оверлеи', ['Нет', 'Уголки', 'Цветы', 'Звёзды', 'Градиент'], demo.activeOverlay, (v) {
                  _checkpoint();
                  setState(() => demo.activeOverlay = v);
                }),
                'Эффекты' => _effectsPanel(c), // ВЫЗОВ ПАНЕЛИ ЭФФЕКТОВ
                'Обрезка' => _choicePanel('соотношение', ['1:1', '4:5', '16:9', '3:2'], demo.cropRatio, (v) {
                  _checkpoint();
                  setState(() => demo.cropRatio = v);
                }),
                _ => const SizedBox(),
              },
            ),
          ),
        ),
      );

  // ПАНЕЛЬ ЭФФЕКТОВ
  Widget _effectsPanel(BuildContext c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _editorLabel('фильтры'),
          space(6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['Оригинал', 'Тёплый', 'Холодный', 'Ч/Б', 'Винтаж'].map((f) {
              final active = demo.activeFilter == f;
              return ChoiceChip(
                label: Text(f, style: const TextStyle(fontSize: 11)),
                selected: active,
                onSelected: (_) {
                  _checkpoint();
                  setState(() => demo.activeFilter = f);
                },
              );
            }).toList(),
          ),
          space(12),
          _editorLabel('интенсивность'),
          Slider(
            value: demo.filterIntensity,
            activeColor: ink,
            onChangeStart: (_) => _checkpoint(),
            onChanged: (v) => setState(() => demo.filterIntensity = v),
          ),
          _editorLabel('прозрачность фото'),
          Slider(
            value: demo.layers.isNotEmpty ? demo.layers[demo.activeLayer.clamp(0, demo.layers.length - 1)].opacity : 1,
            activeColor: ink,
            onChangeStart: (_) => _checkpoint(),
            onChanged: demo.layers.isEmpty ? null : (v) => setState(() {
              demo.layers[demo.activeLayer.clamp(0, demo.layers.length - 1)].opacity = v;
            }),
          ),
        ],
      );

  Widget _choicePanel(String label, List<String> options, String current, ValueChanged<String> onPick) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _editorLabel(label),
          space(10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((o) {
              final active = current == o;
              return GestureDetector(
                onTap: () => onPick(o),
                child: Container(
                  width: 88,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xffe9ecdf) : peach,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: active ? ink : border),
                  ),
                  alignment: Alignment.center,
                  child: Text(o, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: active ? ink : secondary, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
        ],
      );

  double _canvasAspect() => switch (demo.cropRatio) {
        '4:5' => 4 / 5,
        '16:9' => 16 / 9,
        '3:2' => 3 / 2,
        _ => 1,
      };

  // ХОЛСТ (С ПРИМЕНЕНИЕМ ФИЛЬТРОВ И ОБРЕЗКОЙ)
  Widget _canvas(BuildContext c) {
    final matrix = _matrixFor(demo.activeFilter, demo.filterIntensity);
    
    return Container(
      color: const Color(0xfffaf9f4),
      padding: const EdgeInsets.all(12),
      child: Center(
        child: AspectRatio(
          aspectRatio: _canvasAspect(),
          child: RepaintBoundary(
            key: _canvasKey,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border),
              ),
              clipBehavior: Clip.antiAlias, // Обрезаем всё, что выходит за края
              child: ClipRect(             // Двойная защита
                child: ColorFiltered(      // ПРИМЕНЯЕМ ФИЛЬТРЫ
                  colorFilter: ColorFilter.matrix(matrix),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      for (var i = 0; i < demo.layers.length; i++)
                        if (demo.layers[i].visible && demo.layers[i].type == 'photo')
                          _photoWidget(i),
                      if (demo.activeOverlay != 'Нет') _overlayWidget(),
                      if (demo.activeFrame != 'Без рамки') _frameWidget(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoWidget(int i) {
    final layer = demo.layers[i];
    final isActive = layer.imageId == _activePhotoId;
    
    return Positioned(
      left: 0, top: 0, right: 0, bottom: 0,
      child: GestureDetector(
        onTap: () => setState(() => _activePhotoId = layer.imageId),
        onScaleStart: (_) {
          _checkpoint();
          setState(() => _activePhotoId = layer.imageId);
        },
        onScaleUpdate: (d) => setState(() {
          layer.scale = (layer.scale * d.scale).clamp(0.2, 5.0);
          layer.rotation = (layer.rotation + d.rotation).clamp(-3.14, 3.14);
          layer.x += d.focalPointDelta.dx;
          layer.y += d.focalPointDelta.dy;
          _constrain(layer);
        }),
        child: Transform.translate(
          offset: Offset(layer.x, layer.y),
          child: Transform.rotate(
            angle: layer.rotation,
            child: Transform.scale(
              scale: layer.scale,
              child: Opacity(
                opacity: layer.opacity,
                child: Container(
                  decoration: isActive ? BoxDecoration(border: Border.all(color: red, width: 2)) : null,
                  child: _photo(layer.imageId),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlayWidget() {
    switch (demo.activeOverlay) {
      case 'Уголки':
        return IgnorePointer(child: Padding(padding: const EdgeInsets.all(14), child: Stack(children: [_corner(Alignment.topLeft), _corner(Alignment.topRight), _corner(Alignment.bottomLeft), _corner(Alignment.bottomRight)])));
      case 'Цветы':
        return IgnorePointer(child: Stack(children: [Positioned(top: 8, left: 8, child: Text('🌸', style: const TextStyle(fontSize: 24))), Positioned(top: 8, right: 8, child: Text('🌼', style: const TextStyle(fontSize: 24))), Positioned(bottom: 8, left: 8, child: Text('🌷', style: const TextStyle(fontSize: 24))), Positioned(bottom: 8, right: 8, child: Text('🌺', style: const TextStyle(fontSize: 24)))]));
      case 'Звёзды':
        return IgnorePointer(child: Stack(children: [Positioned(top: 10, left: 10, child: Text('✨', style: const TextStyle(fontSize: 24))), Positioned(top: 10, right: 10, child: Text('⭐', style: const TextStyle(fontSize: 24))), Positioned(bottom: 10, left: 10, child: Text('✨', style: const TextStyle(fontSize: 24))), Positioned(bottom: 10, right: 10, child: Text('⭐', style: const TextStyle(fontSize: 24)))]));
      case 'Градиент':
        return IgnorePointer(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black45]))));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _corner(Alignment a) => Align(
        alignment: a,
        child: Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            border: Border(
              top: a == Alignment.topLeft || a == Alignment.topRight ? const BorderSide(color: ink, width: 3) : BorderSide.none,
              bottom: a == Alignment.bottomLeft || a == Alignment.bottomRight ? const BorderSide(color: ink, width: 3) : BorderSide.none,
              left: a == Alignment.topLeft || a == Alignment.bottomLeft ? const BorderSide(color: ink, width: 3) : BorderSide.none,
              right: a == Alignment.topRight || a == Alignment.bottomRight ? const BorderSide(color: ink, width: 3) : BorderSide.none,
            ),
          ),
        ),
      );

  Widget _frameWidget() {
    switch (demo.activeFrame) {
      case 'Классика': return IgnorePointer(child: Container(margin: const EdgeInsets.all(14), decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 10))));
      case 'Полароид': return IgnorePointer(child: Container(decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 12), left: BorderSide(color: Colors.white, width: 12), right: BorderSide(color: Colors.white, width: 12), bottom: BorderSide(color: Colors.white, width: 36)))));
      case 'Два кадра': case 'Три кадра': case 'Коллаж 2×2': return IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 4))));
      case 'Плёнка': return IgnorePointer(child: Container(decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black87, width: 14), bottom: BorderSide(color: Colors.black87, width: 14)))));
      default: return const SizedBox.shrink();
    }
  }

  Widget _bottomBar(BuildContext c) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        height: 120,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _editorLabel('выбранное фото'),
                  space(4),
                  Text(_activePhotoId == null ? 'Нажмите на фото' : 'Фото выбрано', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  space(8),
                  const Text('Перетаскивайте фото пальцем, чтобы двигать его.', style: TextStyle(fontSize: 12, color: secondary)),
                ],
              ),
            ),
            if (_activePhotoId != null)
              IconButton(
                onPressed: () => setState(() {
                  _checkpoint();
                  demo.layers.removeWhere((l) => l.imageId == _activePhotoId);
                  _activePhotoId = null;
                }),
                icon: const Icon(Icons.delete_outline, color: red, size: 28),
              )
          ],
        ),
      );
}