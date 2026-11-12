import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_prototype/main.dart';

import 'app_test.dart' show FakeStorage;

class _BrokenApi extends CatalogApi {
  const _BrokenApi() : super(latency: Duration.zero);
  @override
  Future<List<Product>> fetch() async => throw StateError('API недоступен');
}

class _OneProductApi extends CatalogApi {
  const _OneProductApi() : super(latency: Duration.zero);
  @override
  Future<List<Product>> fetch() async => [
        const Product('test', 'Тестовый товар', 'Описание', 500,
            Icons.photo_outlined, Colors.blue),
      ];
}

Store readyStore() => Store(FakeStorage())
  ..accountEmail = 'user@example.com'
  ..photos = [
    const Photo(id: 'a', name: 'a.jpg', width: 2400, height: 1800, size: 1000),
  ]
  ..inCart = true;

void main() {
  group('МП-03: проект из 10+ фото', () {
    test('порядок сохраняется после перемещения и перезапуска', () async {
      final fs = FakeStorage();
      final photos = List.generate(
        12,
        (i) => Photo(
          id: 'p$i',
          name: 'p$i.jpg',
          width: 2400,
          height: 1800,
          size: 1000 + i,
        ),
      );
      final s = Store(fs)..photos = List.of(photos);
      s.movePhoto(0, 12); // первое фото в конец
      s.movePhoto(5, 2);
      await s.flush();
      final expected = s.photos.map((p) => p.id).toList();
      expect(expected.length, 12);
      expect(expected.last, 'p0');

      final restored = Store(fs);
      await restored.load();
      expect(restored.photos.map((p) => p.id).toList(), expected);
    });
  });

  group('МП-01: каталог из mock API', () {
    tearDown(() => products = List<Product>.of(builtinProducts));

    test('JSON каталога разбирается: цены, сроки, форматы', () {
      final list = parseCatalogJson(
        File('assets/mock_api/catalog.json').readAsStringSync(),
      );
      expect(list.length, 5);
      final photo = list.firstWhere((p) => p.id == 'photo');
      expect(photo.priceKopecks, 130);
      expect(photo.leadTime, '1–2 раб. дн.');
      expect(photo.formats, isNotEmpty);
      final book = list.firstWhere((p) => p.id == 'premium');
      expect(book.pageOptions.length, 3);
    });

    test('некорректные позиции пропускаются, срок нормализуется', () {
      final list = parseCatalogJson(
        '{"products":['
        '{"id":"x","title":"Без цены","priceKopecks":0},'
        '{"id":"y","title":"Нормальный","priceKopecks":100,'
        '"leadMinDays":4,"leadMaxDays":2},'
        '{"id":"y","title":"Дубль","priceKopecks":100}]}',
      );
      expect(list.length, 1);
      expect(list.single.id, 'y');
      expect(list.single.leadTime, '4 раб. дн.');
    });

    test('ответ без products считается ошибкой', () {
      expect(() => parseCatalogJson('{}'), throwsFormatException);
    });

    test('при ошибке API остаётся встроенный каталог', () async {
      await loadCatalog(const _BrokenApi());
      expect(products.length, builtinProducts.length);
      expect(catalogSource, contains('встроенная'));
    });

    test('при успехе каталог берётся из API', () async {
      await loadCatalog(const _OneProductApi());
      expect(products.single.id, 'test');
      expect(catalogSource, 'mock API каталога');
    });

    test('у каждого встроенного продукта есть срок изготовления', () {
      for (final p in builtinProducts) {
        expect(p.leadMinDays, greaterThan(0));
        expect(p.leadMaxDays, greaterThanOrEqualTo(p.leadMinDays));
        expect(p.leadTime, contains('раб. дн.'));
      }
    });
  });

  group('МП-05: сеть и идемпотентность заказа', () {
    test('нет сети: заказ не создан, черновик и корзина целы', () {
      final s = readyStore()..setNetworkMode(NetworkMode.offline);
      expect(() => s.createOrder(), throwsA(isA<NetworkException>()));
      expect(s.orders, isEmpty);
      expect(s.inCart, isTrue);
      expect(s.photos, isNotEmpty);
    });

    test('повтор после возвращения сети создаёт ровно один заказ', () {
      final s = readyStore()..setNetworkMode(NetworkMode.offline);
      expect(() => s.createOrder(), throwsA(isA<NetworkException>()));
      s.setNetworkMode(NetworkMode.online);
      final order = s.createOrder();
      expect(s.orders.length, 1);
      expect(s.inCart, isFalse);
      // Повторное нажатие после успеха не плодит заказы.
      expect(() => s.createOrder(), throwsStateError);
      expect(s.orders.length, 1);
      expect(s.orders.single['id'], order['id']);
    });

    test('потеря ответа: повтор возвращает тот же заказ без дубликата', () {
      final s = readyStore()..setNetworkMode(NetworkMode.lostResponse);
      expect(() => s.createOrder(), throwsA(isA<NetworkException>()));
      expect(s.orders, isEmpty);
      expect(s.inCart, isTrue);
      expect(s.networkMode, NetworkMode.online);
      final first = s.createOrder();
      expect(s.orders.length, 1);
      expect(s.orders.single['id'], first['id']);
      expect(first['idempotencyKey'], isNotNull);
    });

    test('один и тот же ключ даёт один и тот же заказ', () {
      final s = readyStore();
      final a = s.createOrder(idempotencyKey: 'k1');
      s.inCart = true;
      final b = s.createOrder(idempotencyKey: 'k1');
      expect(b['id'], a['id']);
      expect(s.orders.length, 1);
    });

    test('в заказ записывается срок изготовления', () {
      final order = readyStore().createOrder();
      expect(order['leadTime'], isA<String>());
      expect(order['leadTime'], contains('раб. дн.'));
    });
  });

  group('Статусная лента', () {
    testWidgets('показывает все этапы и отмечает пройденные', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OrderTimeline(status: 'Производство')),
        ),
      );
      for (final stage in Store.orderStages) {
        expect(find.text(stage), findsOneWidget);
      }
      // «Принят» и «Модерация» пройдены.
      expect(find.byIcon(Icons.check), findsNWidgets(2));
    });
  });
}
