part of '../main.dart';

class Layer {
  final String id, imageId, type;
  String text;
  double x, y, scale, rotation, opacity;
  bool visible;
  Layer({
    required this.id,
    this.imageId = '',
    this.type = 'photo',
    this.text = '',
    this.x = 0,
    this.y = 0,
    this.scale = 1,
    this.rotation = 0,
    this.opacity = 1,
    this.visible = true,
  });
  factory Layer.fromMap(Map<String, dynamic> m) => Layer(
        id: m['id'] as String? ?? '',
        imageId: m['imageId'] as String? ?? '',
        type: m['type'] == 'text' ? 'text' : 'photo',
        text: m['text'] as String? ?? '',
        x: ((m['x'] as num?)?.toDouble() ?? 0).clamp(-2000, 2000),
        y: ((m['y'] as num?)?.toDouble() ?? 0).clamp(-2000, 2000),
        scale: ((m['scale'] as num?)?.toDouble() ?? 1).clamp(.25, 4),
        rotation: ((m['rotation'] as num?)?.toDouble() ?? 0).clamp(
          -3.14159265,
          3.14159265,
        ),
        opacity: ((m['opacity'] as num?)?.toDouble() ?? 1).clamp(0, 1),
        visible: m['visible'] != false,
      );
  Map<String, dynamic> toMap() => {
        'id': id,
        'imageId': imageId,
        'type': type,
        'text': text,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'opacity': opacity,
        'visible': visible,
      };
}

class _Composition {
  final List<String> selected;
  final List<Layer> layers = [];
  int activeLayer = 0;
  String activeFrame = 'Без рамки',
      activeOverlay = 'Нет',
      activeFilter = 'Оригинал',
      cropRatio = '1:1';
  double filterIntensity = .5;
  _Composition(this.selected);
  factory _Composition.fromMap(Map<String, dynamic>? data, List<Photo> photos) {
    final result = _Composition(photos.map((p) => p.id).toList());
    if (data == null) return result;
    for (final raw in (data['layers'] as List? ?? [])) {
      final layer = Layer.fromMap(Map<String, dynamic>.from(raw as Map));
      if (layer.type == 'text' || result.selected.contains(layer.imageId))
        result.layers.add(layer);
    }
    result.activeLayer = ((data['activeLayer'] as num?)?.toInt() ?? 0).clamp(
      0,
      result.layers.isEmpty ? 0 : result.layers.length - 1,
    );
    result.activeFrame = _allowed(data['frame'], [
      'Без рамки',
      'Классика',
      'Полароид',
      'Два кадра',
      'Три кадра',
      'Коллаж 2×2',
      'Плёнка',
    ]);
    result.activeOverlay = _allowed(data['overlay'], [
      'Нет',
      'Уголки',
      'Цветы',
      'Звёзды',
      'Градиент',
    ]);
    result.activeFilter = _allowed(data['filter'], [
      'Оригинал',
      'Тёплый',
      'Холодный',
      'Ч/Б',
      'Винтаж',
    ]);
    result.cropRatio = _allowed(data['ratio'], ['1:1', '4:5', '16:9', '3:2']);
    result.filterIntensity =
        ((data['intensity'] as num?)?.toDouble() ?? .5).clamp(0, 1);
    return result;
  }
  static String _allowed(Object? value, List<String> choices) =>
      choices.contains(value) ? value as String : choices.first;
  Map<String, dynamic> toMap() => {
        'layers': layers.map((l) => l.toMap()).toList(),
        'activeLayer': activeLayer,
        'frame': activeFrame,
        'overlay': activeOverlay,
        'filter': activeFilter,
        'ratio': cropRatio,
        'intensity': filterIntensity,
      };
  void resetEditorLayers() {
    layers.clear();
    for (var i = 0; i < selected.length; i++) {
      layers.add(
        Layer(
          id: 'photo-$i-${selected[i]}',
          imageId: selected[i],
          visible: i < 4,
        ),
      );
    }
    activeLayer = layers.isEmpty ? 0 : (layers.length - 1).clamp(0, 3);
    activeFrame = 'Без рамки';
    activeOverlay = 'Нет';
    activeFilter = 'Оригинал';
    filterIntensity = .5;
    cropRatio = '1:1';
  }
}
