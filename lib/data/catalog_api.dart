part of '../main.dart';

/// Откуда загружен текущий каталог (показывается на главной).
String catalogSource = 'встроенная копия';

const _catalogIcons = <String, IconData>{
  'book': Icons.menu_book_outlined,
  'photo': Icons.photo_outlined,
  'library': Icons.photo_library_outlined,
};

const _catalogColors = <String, Color>{
  'peach': peach,
  'blue': blue,
  'mint': mint,
  'pink': pink,
  'lilac': Color(0xffe0dce8),
};

/// Разбирает ответ mock API каталога. Некорректные позиции пропускаются,
/// чтобы одна ошибка в данных не ломала весь каталог.
List<Product> parseCatalogJson(String text) {
  final data = jsonDecode(text);
  if (data is! Map || data['products'] is! List) {
    throw const FormatException('Ответ каталога без списка products');
  }
  final result = <Product>[];
  final seen = <String>{};
  for (final raw in data['products'] as List) {
    if (raw is! Map) continue;
    final id = raw['id'];
    final title = raw['title'];
    final price = raw['priceKopecks'];
    if (id is! String || id.isEmpty || !seen.add(id)) continue;
    if (title is! String || title.trim().isEmpty) continue;
    if (price is! num || price <= 0) continue;
    final minDays = (raw['leadMinDays'] as num?)?.toInt() ?? 3;
    final maxDays = (raw['leadMaxDays'] as num?)?.toInt() ?? minDays;
    List<String> strings(Object? v) => v is List
        ? v.whereType<String>().where((e) => e.trim().isNotEmpty).toList()
        : <String>[];
    result.add(
      Product(
        id,
        title,
        raw['description'] as String? ?? '',
        price.toInt(),
        _catalogIcons[raw['icon']] ?? Icons.photo_outlined,
        _catalogColors[raw['color']] ?? peach,
        leadMinDays: minDays < 1 ? 1 : minDays,
        leadMaxDays: maxDays < minDays ? minDays : maxDays,
        formats: strings(raw['formats']),
        pageOptions: strings(raw['pageOptions']),
      ),
    );
  }
  return result;
}

/// Mock API каталога: отдаёт JSON из assets с небольшой задержкой,
/// как настоящий сетевой запрос. Контракт совместим с REST/JSON:
/// GET /catalog -> { products: [...] }.
class CatalogApi {
  static const assetPath = 'assets/mock_api/catalog.json';
  final Duration latency;
  const CatalogApi({this.latency = const Duration(milliseconds: 250)});

  Future<List<Product>> fetch() async {
    await Future<void>.delayed(latency);
    final text = await rootBundle.loadString(assetPath);
    return parseCatalogJson(text);
  }
}

/// Загружает каталог при запуске. Если API недоступен или ответ пуст,
/// остаётся встроенная копия, и приложение продолжает работать.
Future<void> loadCatalog([CatalogApi api = const CatalogApi()]) async {
  try {
    final loaded = await api.fetch();
    if (loaded.isNotEmpty) {
      products = loaded;
      catalogSource = 'mock API каталога';
      return;
    }
  } catch (_) {
    // Используем встроенную копию.
  }
  products = List<Product>.of(builtinProducts);
  catalogSource = 'встроенная копия (API недоступен)';
}
