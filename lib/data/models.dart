part of '../main.dart';

class PickResult {
  final List<Photo> files;
  final List<String> errors;
  PickResult(this.files, this.errors);
}

class Photo {
  final String id, name, crop, frame, effect;
  final bool frameVisible, effectVisible;
  final int width, height, size, turns;
  final double positionX, positionY, brightness;
  const Photo({
    required this.id, required this.name, required this.width, required this.height, required this.size,
    this.turns = 0, this.crop = 'original', this.frame = 'none', this.effect = 'none',
    this.frameVisible = true, this.effectVisible = true, this.positionX = 0, this.positionY = 0, this.brightness = 0,
  });
  factory Photo.fromMap(Map<String, dynamic> m) => Photo(
        id: m['id'] as String, name: m['name'] as String, width: (m['width'] as num).toInt(),
        height: (m['height'] as num).toInt(), size: (m['size'] as num).toInt(),
        turns: ((m['turns'] as num?)?.toInt() ?? 0) % 4,
        crop: const ['original', 'square', 'landscape', 'portrait'].contains(m['crop']) ? m['crop'] as String : 'original',
        frame: const ['none', 'white', 'dark', 'film'].contains(m['frame']) ? m['frame'] as String : 'none',
        effect: const ['none', 'mono', 'warm'].contains(m['effect']) ? m['effect'] as String : 'none',
        frameVisible: m['frameVisible'] != false, effectVisible: m['effectVisible'] != false,
        positionX: ((m['positionX'] as num?)?.toDouble() ?? 0).clamp(-1, 1),
        positionY: ((m['positionY'] as num?)?.toDouble() ?? 0).clamp(-1, 1),
        brightness: ((m['brightness'] as num?)?.toDouble() ?? 0).clamp(-0.3, 0.3),
      );
  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'width': width, 'height': height, 'size': size, 'turns': turns,
        'crop': crop, 'frame': frame, 'effect': effect, 'frameVisible': frameVisible,
        'effectVisible': effectVisible, 'positionX': positionX, 'positionY': positionY, 'brightness': brightness,
      };
  Photo copyWith({
    int? turns, String? crop, String? frame, String? effect, bool? frameVisible,
    bool? effectVisible, double? positionX, double? positionY, double? brightness,
  }) => Photo(
        id: id, name: name, width: width, height: height, size: size,
        turns: turns ?? this.turns, crop: crop ?? this.crop, frame: frame ?? this.frame,
        effect: effect ?? this.effect, frameVisible: frameVisible ?? this.frameVisible,
        effectVisible: effectVisible ?? this.effectVisible, positionX: positionX ?? this.positionX,
        positionY: positionY ?? this.positionY, brightness: brightness ?? this.brightness,
      );
  double get aspectRatio => switch (crop) {
        'square' => 1.0, 'landscape' => 4.0 / 3.0, 'portrait' => 3.0 / 4.0,
        _ => turns.isOdd ? height / width : width / height,
      };
  bool get lowResolution => width < 1600 || height < 1600;
}

class BookLayout {
  final String id, title, description;
  final int columns, slots;
  final double inset;
  const BookLayout(this.id, this.title, this.description, this.columns, this.slots, this.inset);
}

const layouts = <BookLayout>[
  BookLayout('single', 'На всю страницу', 'Одно фото на странице', 1, 1, 0),
  BookLayout('frame', 'С рамкой', 'Одно фото с полями', 1, 1, 12),
  BookLayout('pair', 'Два снимка', 'Два фото рядом', 2, 2, 8),
  BookLayout('grid', 'Коллаж 4', 'Четыре фото на странице', 2, 4, 8),
  BookLayout('pair_h', 'Два этажа', 'Два горизонтальных фото', 1, 2, 8),
  BookLayout('triple_v', 'Три вертикально', 'Три фото друг под другом', 1, 3, 4),
  BookLayout('mosaic_3', 'Мозаика 3', 'Одно большое и два маленьких', 3, 3, 4),
  BookLayout('grid_9', 'Сетка 9', 'Девять маленьких фото', 3, 9, 2),
  BookLayout('hero_top', 'Главное сверху', 'Большое фото и три под ним', 3, 4, 6),
  BookLayout('filmstrip', 'Кинопленка', 'Три кадра в ряд', 3, 3, 0),
];

class Product {
  final String id, title, description;
  final int priceKopecks;
  final IconData icon;
  final Color color;
  final int leadMinDays, leadMaxDays;
  final List<String> formats, pageOptions;
  
  const Product(
    this.id, this.title, this.description, this.priceKopecks, this.icon, this.color, {
    this.leadMinDays = 3, this.leadMaxDays = 5,
    this.formats = const [], this.pageOptions = const [],
  });

  String get leadTime => leadMinDays == leadMaxDays ? '$leadMinDays раб. дн.' : '$leadMinDays–$leadMaxDays раб. дн.';
}

const builtinProducts = <Product>[
  Product(
    'classic', 'Фотокнига Classic', 'Книжная обложка и ламинированные страницы', 8100, Icons.menu_book_outlined, peach,
    leadMinDays: 6, leadMaxDays: 8,
    // НОВЫЕ ФОРМАТЫ ДЛЯ КНИГ
    formats: ['15 × 15 см (Мини)', '20 × 20 см', '21 × 30 см (А4)', '25 × 25 см', '30 × 30 см'],
    pageOptions: ['10 разворотов', '15 разворотов', '20 разворотов'],
  ),
  Product(
    'photo', 'Фотопечать', 'Фотохимическая печать на фотобумаге', 130, Icons.photo_outlined, blue,
    leadMinDays: 1, leadMaxDays: 2,
    // НОВЫЕ ФОРМАТЫ ДЛЯ ПЕЧАТИ
    formats: ['10 × 15 см', '15 × 20 см', '20 × 30 см', 'A4 (21 × 30 см)', 'Панорама (20 × 60 см)'],
  ),
  Product(
    'lite', 'Фотокнига Lite', 'Твёрдая обложка и гибкие страницы', 7000, Icons.menu_book_outlined, mint,
    leadMinDays: 5, leadMaxDays: 7,
    formats: ['15 × 15 см (Мини)', '20 × 20 см', '21 × 30 см (А4)', '25 × 25 см'],
    pageOptions: ['24 страницы', '32 страницы', '40 страниц'],
  ),
  Product(
    'premium', 'Фотокнига Premium', 'Твёрдая обложка, матовая фотобумага', 10050, Icons.menu_book_outlined, pink,
    leadMinDays: 7, leadMaxDays: 10,
    formats: ['20 × 20 см', '21 × 30 см (А4)', '25 × 25 см', '30 × 20 см', '30 × 30 см', '30 × 40 см (XXL)'],
    pageOptions: ['5 разворотов', '10 разворотов', '15 разворотов'],
  ),
  Product(
    'digital', 'Цифровая фотопечать', 'Цифровая печать фотографий', 61, Icons.photo_library_outlined, Color(0xffe0dce8),
    leadMinDays: 1, leadMaxDays: 2,
    formats: ['10 × 15 см', '15 × 20 см', '20 × 30 см', 'A4 (21 × 30 см)'],
  ),
];

List<Product> products = List<Product>.of(builtinProducts);

String money(int value) => '${value ~/ 100},${(value % 100).toString().padLeft(2, '0')} BYN';