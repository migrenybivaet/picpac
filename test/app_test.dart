import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_prototype/main.dart';

class FakeStorage implements AppStorage {
  String? data;
  String? directory;
  List<Photo> next = [];
  List<String> deleted = [];
  String? email, secret, signedIn, adminSignedIn, adminEmail, adminPassword;
  String? supportSignedIn;
  final Map<String, String> credentials = {};
  final Map<String, bool> disabled = {};
  @override
  Future<String?> legacyOwner() async => null;
  @override
  Future<String?> adminState() async => adminSignedIn;
  @override
  Future<String?> supportState() async => supportSignedIn;
  bool ownerConfirmed = false;
  String supportPassword = 'test-support-password';
  bool supportConfigured = true;
  @override
  Future<String> staffAccessState(String role) async => role == 'admin'
      ? (adminEmail == 'admin@picpac.local' ? 'ready' : 'missing')
      : (supportConfigured ? 'ready' : 'missing');
  @override
  Future<bool> verifyDeviceOwner() async => ownerConfirmed;
  @override
  Future<String> setupStaff(String role, String password) async {
    if (!ownerConfirmed) throw PlatformException(code: 'CANCELLED');
    if (role == 'admin') {
      adminEmail = 'admin@picpac.local';
      adminPassword = password;
      adminSignedIn = null;
      return adminEmail!;
    }
    if (role == 'support') {
      supportPassword = password;
      supportConfigured = true;
      supportSignedIn = null;
      return 'support@picpac.local';
    }
    throw PlatformException(code: 'INVALID');
  }

  @override
  Future<String> authenticateSupport(String email, String password) async {
    if (!supportConfigured ||
        email.trim().toLowerCase() != 'support@picpac.local' ||
        password != supportPassword)
      throw PlatformException(code: 'AUTH_FAILED');
    signedIn = null;
    adminSignedIn = null;
    supportSignedIn = email.trim().toLowerCase();
    return supportSignedIn!;
  }

  @override
  Future<void> supportLogout() async {
    supportSignedIn = null;
  }

  @override
  Future<bool> adminExists() async => adminEmail != null;
  @override
  Future<String> authenticateAdmin(
    String address,
    String password, {
    required bool setup,
  }) async {
    final normalized = address.trim().toLowerCase();
    if (setup) {
      if (adminEmail != null) throw PlatformException(code: 'ADMIN_EXISTS');
      adminEmail = normalized;
      adminPassword = password;
    } else if (adminEmail != normalized || adminPassword != password) {
      throw PlatformException(code: 'AUTH_FAILED');
    }
    signedIn = null;
    supportSignedIn = null;
    adminSignedIn = normalized;
    return normalized;
  }

  @override
  Future<void> adminLogout() async {
    adminSignedIn = null;
  }

  @override
  Future<List<Map<String, dynamic>>> adminListUsers() async {
    if (adminSignedIn == null) throw PlatformException(code: 'FORBIDDEN');
    return credentials.keys
        .map(
          (e) => <String, dynamic>{
            'email': e,
            'disabled': disabled[e] ?? false,
          },
        )
        .toList();
  }

  @override
  Future<void> adminSetDisabled(String address, bool value) async {
    if (adminSignedIn == null) throw PlatformException(code: 'FORBIDDEN');
    if (!credentials.containsKey(address))
      throw PlatformException(code: 'NOT_FOUND');
    disabled[address] = value;
  }

  @override
  Future<String?> authState() async => signedIn;
  @override
  Future<String> authenticate(
    String address,
    String password, {
    required bool register,
  }) async {
    final normalized = address.trim().toLowerCase();
    if (register && credentials.containsKey(normalized))
      throw PlatformException(code: 'ACCOUNT_EXISTS');
    if (!register &&
        (credentials[normalized] ?? (email == normalized ? secret : null)) !=
            password) throw PlatformException(code: 'AUTH_FAILED');
    if (!register && disabled[normalized] == true)
      throw PlatformException(code: 'DISABLED');
    if (register) {
      email = normalized;
      secret = password;
      credentials[normalized] = password;
    }
    adminSignedIn = null;
    supportSignedIn = null;
    signedIn = normalized;
    return normalized;
  }

  @override
  Future<void> logout() async {
    signedIn = null;
  }

  @override
  Future<void> deleteAccount() async {
    credentials.remove(signedIn);
    email = null;
    secret = null;
    signedIn = null;
  }

  @override
  Future<String?> load() async => data;
  @override
  Future<String?> photoDirectory() async => directory;
  @override
  Future<void> save(String value) async {
    data = value;
  }

  Photo? segmentResult;
  int segmentationCalls = 0;
  @override
  Future<Photo> segmentPortrait(String sourceId,
      {String? backgroundId, int? color}) async {
    segmentationCalls++;
    if (segmentResult == null) throw PlatformException(code: 'NOT_IMPLEMENTED');
    return segmentResult!;
  }

  @override
  Future<PickResult> pick() async => PickResult(next, []);
  @override
  Future<void> delete(String id) async {
    deleted.add(id);
  }
}

class FailingStorage extends FakeStorage {
  @override
  Future<void> save(String value) async =>
      throw StateError('storage unavailable');
}

const one = Photo(
  id: 'one',
  name: 'summer.jpg',
  width: 2200,
  height: 1800,
  size: 1234,
);
const two = Photo(
  id: 'two',
  name: 'small.png',
  width: 800,
  height: 600,
  size: 567,
);

Future<void> press(WidgetTester tester, Finder finder) async {
  final label = finder.description;
  expect(finder, findsWidgets);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'after tapping $label');
}

Future<void> fillRegistration(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'ФИО'),
    'Иванова Анна Петровна',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Телефон'),
    '+375291234567',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Адрес доставки'),
    'Минск, улица Ленина 10',
  );
}

void main() {
  test('Цена, скидка и доставка рассчитываются в копейках', () {
    final s = Store(FakeStorage())..photos = [one, two];
    expect(s.itemsPrice, 8100);
    s.quantity = 2;
    s.promo = true;
    expect(s.subtotal, 14580);
    expect(s.deliveryPrice, 500);
    s.delivery = 'Самовывоз';
    expect(s.deliveryPrice, 0);
    s.productIndex = 1;
    s.formatIndex = 1;
    s.quantity = 1;
    s.promo = false;
    expect(s.itemsPrice, 340);
  });
  test(
    'Фото и порядок сохраняются, удалённый файл удаляется из хранилища',
    () async {
      final fs = FakeStorage()..next = [one, two];
      final s = Store(fs);
      await s.addPhotos();
      s.movePhoto(0, 2);
      await s.flush();
      final restored = Store(fs);
      await restored.load();
      expect(restored.photos.map((p) => p.name).toList(), [
        'small.png',
        'summer.jpg',
      ]);
      expect(restored.lowCount, 1);
      await restored.removePhoto(0);
      expect(fs.deleted, ['two']);
      final saved = jsonDecode(fs.data!) as Map<String, dynamic>;
      expect((saved['draftBuckets']['guest']['photos'] as List).length, 1);
    },
  );
  test(
      'Каталог основан на товарах PicPac, неподдержанные старые товары мигрируют безопасно',
      () async {
    expect(
      products.map((p) => p.title),
      containsAll([
        'Фотопечать',
        'Фотокнига Lite',
        'Фотокнига Classic',
        'Фотокнига Premium',
        'Цифровая фотопечать',
      ]),
    );
    expect(products.map((p) => p.title), isNot(contains('Фотокружка')));
    final fs = FakeStorage()
      ..data = jsonEncode({
        'product': 3,
        'format': 1,
        'pages': 0,
        'photos': [one.toMap()],
        'inCart': true,
      });
    final s = Store(fs);
    await s.load();
    expect(s.photos, isEmpty);
    expect(s.unassignedLegacyDraft, isNotNull);
    fs.ownerConfirmed = true;
    s.setAccount(await fs.authenticate('migration@example.com', 'password1',
        register: true));
    await s.claimLegacyDrafts();
    s.restoreProject(s.savedProjects.single['id'].toString());
    expect(s.photos.single.name, 'summer.jpg');
    expect(s.product.id, 'classic');
    expect(s.inCart, isFalse);
    expect(s.needsReview, isTrue);
    s.changed();
    await s.flush();
    final s2 = Store(fs);
    await s2.load();
    expect(s2.photos.single.name, 'summer.jpg');
    s2.productIndex = 3;
    expect(s2.formats, contains('25 × 25 см'));
    expect(s2.pages, '5 разворотов');
    s2.productIndex = 4;
    expect(s2.configurable, isTrue);
    expect(s2.formats, contains('10 × 15 см'));
  });
  test('Обмен данными с Android picker корректно разбирается', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('by.picpac.demo/storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pickPhotos')
        return {
          'photos': [one.toMap()],
          'errors': ['Ошибка файла'],
        };
      return null;
    });
    final r = await AndroidStorage().pick();
    expect(r.files.single.name, 'summer.jpg');
    expect(r.errors.single, 'Ошибка файла');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  testWidgets('Дополнительные форматы отображаются и сохраняются', (
    tester,
  ) async {
    final fs = FakeStorage()
      ..next = [
        const Photo(
          id: 'sample.webp',
          name: 'снимок.WEBP',
          width: 2000,
          height: 2000,
          size: 1200,
        ),
        const Photo(
          id: 'converted.png',
          name: 'фото.HEIC',
          width: 2000,
          height: 2000,
          size: 1200,
        ),
      ];
    final s = Store(fs);
    await tester.pumpWidget(MaterialApp(home: PhotosPage(store: s)));
    await tester.pumpAndSettle();
    await press(tester, find.text('Выбрать из галереи'));
    expect(find.text('снимок.WEBP'), findsOneWidget);
    expect(find.text('фото.HEIC'), findsOneWidget);
    await s.flush();
    final restored = Store(fs);
    await restored.load();
    expect(restored.photos.map((p) => p.name), ['снимок.WEBP', 'фото.HEIC']);
  });
  testWidgets('Проход по основному сценарию с выбором фото и демо-заказом', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = FakeStorage()..next = [one, two];
    final s = Store(fs);
    await tester.pumpWidget(PicPacApp(store: s));
    await tester.pumpAndSettle();
    await press(tester, find.text('Продолжить без входа'));
    await press(tester, find.byIcon(Icons.arrow_forward));
    await press(tester, find.text('Добавить фотографии'));
    expect(find.text('Выбрано: 0'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Продолжить'))
          .onPressed,
      isNull,
    );
    await press(tester, find.text('Выбрать из галереи'));
    expect(s.photos.length, 2);
    await press(tester, find.text('Продолжить'));
    await press(tester, find.text('Проверить проект'));
    expect(find.text('Низкое разрешение: 1'), findsOneWidget);
    await press(tester, find.text('Продолжить с этими фото'));
    final promo = find.widgetWithText(TextField, 'Промокод');
    await tester.ensureVisible(promo);
    await tester.enterText(promo, 'PIC10');
    await press(tester, find.text('Применить'));
    expect(s.subtotal, 7290);
    await press(tester, find.text('Оформить · 72,90 BYN'));
    expect(find.text('Нет аккаунта? Зарегистрироваться'), findsOneWidget);
    await press(tester, find.text('Нет аккаунта? Зарегистрироваться'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'demo@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Пароль'),
      'password123',
    );
    await fillRegistration(tester);
    await press(tester, find.text('Зарегистрироваться'));
    await press(tester, find.text('Перенести проект'));
    expect(find.text('Оформление'), findsWidgets);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'ФИО'))
          .controller!
          .text,
      'Иванова Анна Петровна',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Телефон'))
          .controller!
          .text,
      '+375291234567',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Адрес доставки'))
          .controller!
          .text,
      'Минск, улица Ленина 10',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'ФИО'),
      'Иванова Анна',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Телефон'),
      '+375291234567',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Адрес доставки'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Адрес доставки'),
      'Минск, улица 1',
    );
    await tester.scrollUntilVisible(
      find.byType(CheckboxListTile),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await press(tester, find.byType(CheckboxListTile));
    await press(tester, find.text('Оформить демо-заказ'));
    expect(find.text('Демо-заказ создан'), findsOneWidget);
    expect(s.orders.length, 1);
    expect(s.inCart, false);
    expect(s.orders.single['total'], 7790);
    await press(tester, find.text('К заказам'));
    await press(tester, find.text('Подробнее'));
    expect(find.text('Принят'), findsOneWidget);
    expect(find.text('Имитировать следующий статус'), findsNothing);
    expect(s.orders.single['status'], 'Принят');
    expect(s.notifications.length, 1);
    await s.flush();
    // Errors are automatically reported by the test binding.
  });
  testWidgets('Основные экраны помещаются на небольшом Android-экране', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = Store(FakeStorage())
      ..photos = [one, two]
      ..inCart = true;
    for (final page in <Widget>[
      Welcome(store: s),
      AuthPage(store: s),
      MainTabs(store: s),
      ProductPage(store: s),
      PhotosPage(store: s),
      Editor(store: s),
      TemplatesPage(store: s),
      PhotoEditor(store: s, photo: one),
      PhotoComposer(store: s),
      CheckPage(store: s),
      Cart(store: s),
      Checkout(store: s),
    ]) {
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Screen: ${page.runtimeType}',
      );
    }
  });

  testWidgets('Можно заранее выбрать готовый макет фотокниги', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = FakeStorage();
    final s = Store(fs);
    await tester.pumpWidget(MaterialApp(home: ProductPage(store: s)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Выбрать'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await press(tester, find.text('Выбрать'));
    await press(tester, find.text('Два снимка'));
    expect(s.layoutId, 'pair');
    await tester.ensureVisible(find.byType(Slider));
    await tester.drag(find.byType(Slider), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(s.layoutMargin, greaterThan(0));
    await press(tester, find.text('Готово'));
    await s.flush();
    final restored = Store(fs);
    await restored.load();
    expect(restored.layoutId, 'pair');
    expect(restored.layoutMargin, s.layoutMargin);
  });

  testWidgets('Поворот, кадрирование и яркость сохраняются в проекте', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = FakeStorage();
    final s = Store(fs)..photos = [one];
    await tester.pumpWidget(MaterialApp(home: Editor(store: s)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('summer.jpg'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await press(tester, find.text('summer.jpg'));
    await press(tester, find.byTooltip('Повернуть вправо'));
    await press(tester, find.text('1:1'));
    await press(tester, find.text('Эффекты'));
    await press(tester, find.text('Тёплый'));
    await tester.scrollUntilVisible(
      find.text('Яркость'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final slider = find.byType(Slider).last;
    await tester.ensureVisible(slider);
    await tester.drag(slider, const Offset(45, 0));
    await tester.pumpAndSettle();
    await press(tester, find.text('Рамки'));
    await press(tester, find.text('Полароид'));
    await press(tester, find.text('Слои'));
    await tester.scrollUntilVisible(
      find.widgetWithText(SwitchListTile, 'Рамка'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await press(tester, find.widgetWithText(SwitchListTile, 'Рамка'));
    await press(tester, find.text('Сохранить'));
    expect(s.photos.single.frame, 'film');
    expect(s.photos.single.frameVisible, false);
    expect(s.photos.single.effect, 'warm');
    expect(s.photos.single.turns, 1);
    expect(s.photos.single.crop, 'square');
    expect(s.photos.single.brightness, greaterThan(0));
    await s.flush();
    final restored = Store(fs);
    await restored.load();
    expect(restored.photos.single.frame, 'film');
    expect(restored.photos.single.frameVisible, false);
    expect(restored.photos.single.effect, 'warm');
    expect(restored.photos.single.turns, 1);
    expect(restored.photos.single.crop, 'square');
    expect(restored.photos.single.brightness, greaterThan(0));
  });

  testWidgets('Предпросмотр отображает выбранное изображение и поворот', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('picpac-preview-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 50, 50),
      Paint()..color = const Color(0xffff0000),
    );
    canvas.drawRect(
      const Rect.fromLTWH(50, 0, 50, 50),
      Paint()..color = const Color(0xff0000ff),
    );
    final image = recorder.endRecording().toImageSync(100, 50);
    final provider = FileImage(File('${dir.path}/fixture.png'));
    final cacheKey = await provider.obtainKey(ImageConfiguration.empty);
    PaintingBinding.instance.imageCache.putIfAbsent(
      cacheKey,
      () => OneFrameImageStreamCompleter(
        SynchronousFuture(ImageInfo(image: image)),
      ),
    );
    final s = Store(FakeStorage())..photoDirectory = dir.path;
    const photo = Photo(
      id: 'fixture.png',
      name: 'test.png',
      width: 100,
      height: 50,
      size: 100,
    );
    final key = GlobalKey();
    Future<List<int>> pixel(int x, int y) async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = boundary.toImageSync(pixelRatio: 1);
      final bytes = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final offset = (y * image.width + x) * 4;
      return bytes!.buffer.asUint8List().sublist(offset, offset + 4);
    }

    Future<void> show(Photo p) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              child: RepaintBoundary(
                key: key,
                child: PhotoPreview(store: s, photo: p),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
    }

    await show(photo);
    final left = await pixel(40, 50), right = await pixel(160, 50);
    expect(left[0], greaterThan(200));
    expect(left[2], lessThan(50));
    expect(right[2], greaterThan(200));
    expect(right[0], lessThan(50));
    await show(photo.copyWith(turns: 1));
    final top = await pixel(100, 100), bottom = await pixel(100, 300);
    expect(top[0], greaterThan(200));
    expect(bottom[2], greaterThan(200));
  });

  testWidgets('Перенесённый редактор сохраняет композицию и слои', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = FakeStorage();
    final s = Store(fs)..photos = [one, two];
    await tester.pumpWidget(MaterialApp(home: Editor(store: s)));
    await tester.pumpAndSettle();
    await press(tester, find.text('Открыть фоторедактор'));
    expect(find.text('ОРИГИНАЛ'), findsOneWidget);
    await press(tester, find.text('Макеты'));
    await press(tester, find.text('Коллаж 2×2'));
    await press(tester, find.text('Эффекты'));
    await press(tester, find.text('Тёплый'));
    await press(tester, find.text('Текст'));
    await tester.enterText(find.byType(TextField), 'Привет');
    await press(tester, find.text('Добавить слой'));
    expect(find.text('Привет'), findsWidgets);
    await press(tester, find.text('Сохранить'));
    expect(s.composition!['frame'], 'Коллаж 2×2');
    expect(s.composition!['filter'], 'Тёплый');
    expect((s.composition!['layers'] as List).length, 3);
    await s.flush();
    final restored = Store(fs);
    await restored.load();
    expect(restored.composition!['frame'], 'Коллаж 2×2');
    expect((restored.composition!['layers'] as List).last['text'], 'Привет');
    await press(tester, find.text('Открыть фоторедактор'));
    expect(find.text('Привет'), findsWidgets);
  });
  testWidgets('Локальная регистрация, выход и повторный вход', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = FakeStorage();
    final s = Store(fs);
    await tester.pumpWidget(PicPacApp(store: s));
    await tester.pumpAndSettle();
    expect(find.text('Продолжить без входа'), findsOneWidget);
    await press(tester, find.text('Нет аккаунта? Зарегистрироваться'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Пароль'),
      'password123',
    );
    await fillRegistration(tester);
    await press(tester, find.text('Зарегистрироваться'));
    expect(s.accountEmail, 'user@example.com');
    final restored = Store(fs);
    await restored.load();
    expect(restored.accountEmail, 'user@example.com');
    await press(tester, find.text('Профиль'));
    await press(tester, find.text('Выйти из аккаунта'));
    expect(s.accountEmail, isNull);
    await press(tester, find.text('Войти или зарегистрироваться'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Пароль'),
      'wrongpass',
    );
    await press(tester, find.text('Войти'));
    expect(find.text('Неверный email или пароль.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Пароль'),
      'password123',
    );
    await press(tester, find.text('Войти'));
    expect(s.accountEmail, 'user@example.com');
    await press(tester, find.text('Профиль'));
    await press(tester, find.text('Удалить локальный аккаунт'));
    await press(tester, find.text('Удалить'));
    expect(s.accountEmail, isNull);
    expect(fs.email, isNull);
  });

  testWidgets('Поддержка требует вход и возвращает к чату', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = FakeStorage();
    final s = Store(fs);
    await tester.pumpWidget(MaterialApp(home: MainTabs(store: s, initial: 3)));
    await tester.pumpAndSettle();
    await press(tester, find.text('Поддержка'));
    expect(find.text('Нет аккаунта? Зарегистрироваться'), findsOneWidget);
    await press(tester, find.text('Нет аккаунта? Зарегистрироваться'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'guest@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Пароль'),
      'password123',
    );
    await fillRegistration(tester);
    await press(tester, find.text('Зарегистрироваться'));
    expect(find.text('Отправить'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Сообщение'),
      'Где заказ?',
    );
    await press(tester, find.text('Отправить'));
    expect(s.supportMessages.length, 1);
    expect(s.unreadCount, 0);
    expect(find.text('Где заказ?'), findsOneWidget);
    await s.flush();
    final restored = Store(fs);
    await restored.load();
    expect(restored.supportMessages.length, 1);
    expect(restored.unreadCount, 0);
  });

  testWidgets('Профиль проверяет ссылки и сохраняет тестовую карту', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = FakeStorage()..signedIn = 'user@example.com';
    final s = Store(fs)..accountEmail = 'user@example.com';
    await tester.pumpWidget(MaterialApp(home: MainTabs(store: s, initial: 3)));
    await tester.pumpAndSettle();
    await press(tester, find.text('Личные данные и соцсети'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ФИО'),
      'Будишевский Ариан',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Телефон'),
      '+375 29 123-45-67',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Адрес доставки'),
      'Минск, улица 1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ВКонтакте (https://...)'),
      'не ссылка',
    );
    await press(tester, find.text('Сохранить'));
    expect(find.text('Введите ссылку вида https://...'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ВКонтакте (https://...)'),
      'https://vk.com/test',
    );
    await press(tester, find.text('Сохранить'));
    expect(s.profileName, 'Будишевский Ариан');
    expect(s.profilePhone, '+375 29 123-45-67');
    expect(s.profileAddress, 'Минск, улица 1');
    expect(s.socialProfiles['vk'], 'https://vk.com/test');
    await press(
        tester, find.text('Карта не добавлена · нажмите, чтобы добавить'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Последние 4 цифры тестовой карты'),
      '4242',
    );
    await press(tester, find.text('Добавить тестовую карту'));
    expect(s.cardLast4, '4242');
    await s.flush();
    final restored = Store(fs);
    await restored.load();
    expect(restored.cardLast4, '4242');
    expect(restored.profileName, 'Будишевский Ариан');
    expect(restored.profilePhone, '+375 29 123-45-67');
  });

  testWidgets('Слой можно увеличить и не потерять за краем', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = Store(FakeStorage())..photos = [one, two];
    await tester.pumpWidget(MaterialApp(home: Editor(store: s)));
    await tester.pumpAndSettle();
    await press(tester, find.text('Открыть фоторедактор'));
    final layer = find.byKey(const ValueKey('layer-photo-1-two'));
    expect(layer, findsOneWidget);
    final center = tester.getCenter(layer);
    final p1 = await tester.startGesture(
      center + const Offset(-30, 0),
      pointer: 11,
    );
    final p2 = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 12,
    );
    await p1.moveTo(center + const Offset(-65, 0));
    await p2.moveTo(center + const Offset(65, 0));
    await tester.pump();
    await p1.up();
    await p2.up();
    await tester.pumpAndSettle();
    await tester.drag(layer, const Offset(3000, 0));
    await tester.pumpAndSettle();
    await press(tester, find.text('Сохранить'));
    final l = (s.composition!['layers'] as List).last as Map<String, dynamic>;
    expect(l['scale'], greaterThan(1));
    expect((l['x'] as num).abs(), lessThan(1000));
  });

  test('Заказ нельзя создать без входа и пустую корзину', () {
    final s = Store(FakeStorage())
      ..photos = [one]
      ..inCart = true;
    expect(() => s.createOrder(), throwsStateError);
    s.accountEmail = 'demo@example.com';
    final order = s.createOrder();
    expect(order['status'], 'Принят');
    expect(s.unreadCount, 1);
    expect(() => s.createOrder(), throwsStateError);
  });

  testWidgets('Уведомления отображаются и отмечаются прочитанными', (
    tester,
  ) async {
    final s = Store(FakeStorage());
    s.notifyLocal('Демо-заказ', 'Тестовое событие');
    await tester.pumpWidget(MaterialApp(home: MainTabs(store: s)));
    await tester.pumpAndSettle();
    await press(tester, find.byTooltip('Уведомления'));
    expect(find.text('Демо-заказ'), findsOneWidget);
    await press(tester, find.text('Демо-заказ'));
    expect(s.unreadCount, 0);
  });

  testWidgets('При ошибке записи заказ не подтверждается', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = Store(FailingStorage())
      ..accountEmail = 'user@example.com'
      ..photos = [one]
      ..inCart = true;
    await tester.pumpWidget(MaterialApp(home: Checkout(store: s)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'ФИО'),
      'Иванова Анна',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Телефон'),
      '+375291234567',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Адрес доставки'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Адрес доставки'),
      'Минск, улица 1',
    );
    await tester.scrollUntilVisible(
      find.byType(CheckboxListTile),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await press(tester, find.byType(CheckboxListTile));
    await press(tester, find.text('Оформить демо-заказ'));
    expect(s.orders, isEmpty);
    expect(s.inCart, isTrue);
    expect(
      find.text('Не удалось сохранить заказ. Попробуйте ещё раз.'),
      findsOneWidget,
    );
  });

  testWidgets('Редактор записывает локальный PNG-предпросмотр', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('picpac-output-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final recorder = ui.PictureRecorder();
    Canvas(
      recorder,
    ).drawRect(const Rect.fromLTWH(0, 0, 100, 50), Paint()..color = Colors.red);
    final image = recorder.endRecording().toImageSync(100, 50);
    final provider = FileImage(File('${dir.path}/fixture.png'));
    final key = await provider.obtainKey(ImageConfiguration.empty);
    PaintingBinding.instance.imageCache.putIfAbsent(
      key,
      () => OneFrameImageStreamCompleter(
        SynchronousFuture(ImageInfo(image: image)),
      ),
    );
    final fs = FakeStorage()..directory = dir.path;
    final photo = const Photo(
      id: 'fixture.png',
      name: 'photo.png',
      width: 100,
      height: 50,
      size: 10,
    );
    final s = Store(fs)
      ..photos = [photo]
      ..photoDirectory = dir.path;
    await tester.pumpWidget(MaterialApp(home: Editor(store: s)));
    await tester.pumpAndSettle();
    await press(tester, find.text('Открыть фоторедактор'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Сохранить'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(s.composition, isNotNull);
    final path = '${dir.path}/${s.composition!['preview']}';
    expect(File(path).existsSync(), isTrue);
    expect(File(path).readAsBytesSync().take(8).toList(), [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
    ]);
  });

  testWidgets('Пустой проект нельзя оформить', (tester) async {
    final s = Store(FakeStorage());
    await tester.pumpWidget(MaterialApp(home: Editor(store: s)));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Проверить проект'),
          )
          .onPressed,
      isNull,
    );
  });
  test('Заказы и профили разделены между локальными пользователями', () async {
    final fs = FakeStorage();
    final s = Store(fs)
      ..photos = [one]
      ..inCart = true;
    s.setAccount(
      await fs.authenticate('first@example.com', 'password1', register: true),
      transferGuestProject: true,
    );
    s.profileName = 'Первый';
    s.changed();
    final order = s.createOrder(
      customerName: 'Первый',
      phone: '+375291234567',
      address: 'Минск',
    );
    expect(order['account'], 'first@example.com');
    s.setAccount(
      await fs.authenticate('second@example.com', 'password2', register: true),
      transferGuestProject: true,
    );
    expect(s.myOrders, isEmpty);
    expect(s.profileName, isEmpty);
    s.profileName = 'Второй';
    s.changed();
    await s.flush();
    s.setAccount(
      await fs.authenticate('first@example.com', 'password1', register: false),
    );
    expect(s.myOrders.single['account'], 'first@example.com');
    expect(s.profileName, 'Первый');
    final restored = Store(fs);
    await restored.load();
    expect(restored.profileName, 'Первый');
    expect(restored.myOrders.length, 1);
  });
  test('Статус меняет только администратор и уведомление адресное', () async {
    final fs = FakeStorage();
    final s = Store(fs)
      ..photos = [one]
      ..inCart = true;
    s.setAccount(
      await fs.authenticate('first@example.com', 'password1', register: true),
      transferGuestProject: true,
    );
    final order = s.createOrder();
    await expectLater(
      s.adminSetOrderStatus(order, 'Модерация'),
      throwsStateError,
    );
    s.setAdmin(
      await fs.authenticateAdmin('admin@example.com', 'password3', setup: true),
    );
    await s.adminSetOrderStatus(order, 'Модерация');
    expect(order['status'], 'Модерация');
    expect(s.notifications.first['owner'], 'first@example.com');
    await expectLater(
      s.adminSetOrderStatus(order, 'Несуществующий'),
      throwsStateError,
    );
    s.setAccount(
      await fs.authenticate('first@example.com', 'password1', register: false),
    );
    expect(s.visibleNotifications.first['title'], 'Статус заказа');
  });
  test('Администратор блокирует и разблокирует вход', () async {
    final fs = FakeStorage();
    await fs.authenticate('user@example.com', 'password1', register: true);
    await expectLater(
      fs.adminSetDisabled('user@example.com', true),
      throwsA(isA<PlatformException>()),
    );
    await fs.authenticateAdmin('admin@example.com', 'password2', setup: true);
    await fs.adminSetDisabled('user@example.com', true);
    await expectLater(
      fs.authenticate('user@example.com', 'password1', register: false),
      throwsA(isA<PlatformException>()),
    );
    await fs.adminSetDisabled('user@example.com', false);
    expect(
      await fs.authenticate('user@example.com', 'password1', register: false),
      'user@example.com',
    );
  });
  testWidgets('Администратор отвечает пользователю', (tester) async {
    final fs = FakeStorage();
    final s = Store(fs);
    s.setAccount(
      await fs.authenticate('user@example.com', 'password1', register: true),
      transferGuestProject: true,
    );
    s.supportMessages.add({
      'owner': 'user@example.com',
      'order': '',
      'sender': 'Вы',
      'text': 'Где заказ?',
    });
    s.setAdmin(
      await fs.authenticateAdmin('admin@example.com', 'password2', setup: true),
    );
    await tester.pumpWidget(MaterialApp(home: AdminSupport(store: s)));
    await tester.pumpAndSettle();
    await press(tester, find.text('Ответить'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Ответ'),
      'Мы проверяем заказ',
    );
    await press(tester, find.text('Отправить ответ'));
    expect(s.supportMessages.last['sender'], 'Поддержка');
    expect(s.notifications.first['owner'], 'user@example.com');
  });
  testWidgets('Первичная настройка администратора и работа со статусом', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = FakeStorage()..ownerConfirmed = true;
    await fs.setupStaff('admin', 'a-strong-admin-password');
    final s = Store(fs)
      ..photos = [one]
      ..inCart = true;
    s.setAccount(
      await fs.authenticate('user@example.com', 'password1', register: true),
      transferGuestProject: true,
    );
    final order = s.createOrder(
      customerName: 'Анна',
      phone: '+375291234567',
      address: 'Минск',
    );
    await tester.pumpWidget(MaterialApp(home: MainTabs(store: s, initial: 3)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Вход администратора'), 200,
        scrollable: find.byType(Scrollable).first);
    await press(tester, find.text('Вход администратора'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Email администратора'),
      'admin@picpac.local',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Пароль'),
      'a-strong-admin-password',
    );
    await press(tester, find.text('Войти'));
    expect(find.text('Панель управления'), findsOneWidget);
    await press(tester, find.text('Заказы'));
    await press(tester, find.textContaining(order['id'] as String));
    await press(tester, find.text('Модерация'));
    expect(order['status'], 'Модерация');
    expect(s.notifications.first['owner'], 'user@example.com');
  });
  test('Новый проект пустой, а прежний черновик восстанавливается', () async {
    final fs = FakeStorage();
    final s = Store(fs)
      ..photos = [one, two]
      ..productIndex = 1
      ..formatIndex = 1;
    final oldId = s.currentProjectId;
    s.composition = {'layers': [], 'frame': 'Два кадра'};
    s.startNewProject();
    expect(s.photos, isEmpty);
    expect(s.composition, isNull);
    expect(s.savedProjects.length, 1);
    s.photos = [two];
    s.changed();
    await s.flush();
    final restored = Store(fs);
    await restored.load();
    expect(restored.photos.map((p) => p.id), ['two']);
    restored.restoreProject(oldId);
    expect(restored.photos.map((p) => p.id), ['one', 'two']);
    expect(restored.product.id, 'photo');
    expect(restored.formatIndex, 1);
    expect(restored.composition!['frame'], 'Два кадра');
    expect(restored.savedProjects.length, 1);
    await restored.removePhoto(1);
    expect(
      fs.deleted,
      isNot(contains('two')),
    ); // still referenced by other draft
  });
  testWidgets('Быстрый заказ: галерея, предупреждение, вход, оформление', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = FakeStorage()..next = [one, two];
    final s = Store(fs);
    await tester.pumpWidget(PicPacApp(store: s));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
    await press(tester, find.text('Продолжить без входа'));
    await press(tester, find.text('Быстрый заказ фото'));
    expect(s.photos, isEmpty);
    await press(tester, find.text('Выбрать из галереи'));
    expect(s.photos.length, 2);
    expect(find.textContaining('К оформлению'), findsOneWidget);
    await press(tester, find.textContaining('К оформлению'));
    expect(find.text('Проверьте качество'), findsOneWidget);
    await press(tester, find.text('Продолжить с этими фото'));
    await press(tester, find.text('Нет аккаунта? Зарегистрироваться'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'fast@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Пароль'),
      'password123',
    );
    await fillRegistration(tester);
    await press(tester, find.text('Зарегистрироваться'));
    await press(tester, find.text('Перенести проект'));
    expect(find.text('Оформление'), findsWidgets);
    expect(s.product.id, 'photo');
    expect(s.inCart, isTrue);
  });
  testWidgets('Тестовая оплата: отказ не создаёт заказ, успех создаёт', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = FakeStorage();
    final s = Store(fs)
      ..photos = [one]
      ..inCart = true;
    s.setAccount(
      await fs.authenticate('pay@example.com', 'password123', register: true),
      transferGuestProject: true,
    );
    await tester.pumpWidget(MaterialApp(home: Checkout(store: s)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'ФИО'),
      'Иванова Анна',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Телефон'),
      '+375291234567',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Адрес доставки'),
      'Минск, улица 1',
    );
    await tester.scrollUntilVisible(
      find.text('Банковская карта'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await press(tester, find.text('Банковская карта'));
    await tester.scrollUntilVisible(
      find.byType(CheckboxListTile),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await press(tester, find.byType(CheckboxListTile));
    await press(tester, find.text('Оформить демо-заказ'));
    await press(tester, find.text('Отклонить оплату'));
    expect(s.orders, isEmpty);
    await press(tester, find.text('Оформить демо-заказ'));
    await press(tester, find.text('Имитировать успех'));
    expect(s.orders.single['payment'], 'Тестовая оплата: успешно');
    expect(s.profilePhone, '+375291234567');
    await s.flush();
    final restored = Store(fs);
    await restored.load();
    expect(restored.profilePhone, '+375291234567');
  });
  testWidgets('Готовые идеи редактора, сравнение и отмена', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = Store(FakeStorage())..photos = [one, two];
    await tester.pumpWidget(MaterialApp(home: PhotoComposer(store: s)));
    await tester.pumpAndSettle();
    await press(tester, find.text('Макеты'));
    await press(tester, find.text('Плёночный день'));
    await press(tester, find.byTooltip('Отменить'));
    await press(tester, find.byTooltip('Повторить'));
    await press(tester, find.text('Сравнить с оригиналом'));
    expect(find.text('Показать результат'), findsOneWidget);
    await press(tester, find.text('Показать результат'));
    await press(tester, find.text('Сохранить'));
    expect(s.composition!['frame'], 'Плёнка');
    expect(s.composition!['filter'], 'Винтаж');
  });
  test(
    'Добавление фото добавляет слой и обновляет устаревший предпросмотр',
    () async {
      final fs = FakeStorage()..next = [two];
      final s = Store(fs)..photos = [one];
      s.composition = {
        'layers': [
          {'id': 'first', 'imageId': 'one', 'type': 'photo'},
        ],
        'preview': 'old.png',
      };
      await s.addPhotos();
      expect((s.composition!['layers'] as List).length, 2);
      expect(s.composition!.containsKey('preview'), isFalse);
      await s.removePhoto(0);
      expect((s.composition!['layers'] as List).single['imageId'], 'two');
    },
  );
  testWidgets('Создание проекта не переносит старые фото', (tester) async {
    final fs = FakeStorage();
    final s = Store(fs)..photos = [one];
    await tester.pumpWidget(MaterialApp(home: MainTabs(store: s)));
    await tester.pumpAndSettle();
    await press(tester, find.text('Быстрый заказ фото'));
    expect(find.text('Создать новый проект?'), findsOneWidget);
    await press(tester, find.text('Создать новый'));
    expect(s.photos, isEmpty);
    expect(s.savedProjects.length, 1);
    expect(find.text('Выбрано фото: 0'), findsOneWidget);
  });
  testWidgets('Макет из трёх кадров сохраняется', (tester) async {
    final s = Store(FakeStorage())..photos = [one, two];
    await tester.pumpWidget(MaterialApp(home: Editor(store: s)));
    await tester.pumpAndSettle();
    await press(tester, find.text('Открыть фоторедактор'));
    await press(tester, find.text('Макеты'));
    await tester.scrollUntilVisible(
      find.text('Три кадра'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await press(tester, find.text('Три кадра'));
    await press(tester, find.text('Сохранить'));
    expect(s.composition!['frame'], 'Три кадра');
  });
  testWidgets('Слой коллажа остаётся в пределах своей ячейки', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = Store(FakeStorage())..photos = [one, two];
    await tester.pumpWidget(MaterialApp(home: Editor(store: s)));
    await tester.pumpAndSettle();
    await press(tester, find.text('Открыть фоторедактор'));
    await press(tester, find.text('Макеты'));
    await tester.scrollUntilVisible(
      find.text('Коллаж 2×2'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await press(tester, find.text('Коллаж 2×2'));
    await press(tester, find.text('Макеты'));
    final layer = find.byKey(const ValueKey('layer-photo-1-two'));
    final width = tester.getSize(layer).width;
    await tester.drag(layer, const Offset(3000, 0));
    await tester.pumpAndSettle();
    await press(tester, find.text('Сохранить'));
    final state =
        (s.composition!['layers'] as List).last as Map<String, dynamic>;
    expect((state['x'] as num).abs(), lessThanOrEqualTo(width));
  });
  test('Модерация заказа, роли и сохранность исходных файлов', () async {
    final dir = await Directory.systemTemp.createTemp('moderation');
    addTearDown(() => dir.delete(recursive: true));
    const photo = Photo(
      id: '12345678-abcd-1234-abcd-123456789abc.jpg',
      name: 'photo.jpg',
      width: 2000,
      height: 1500,
      size: 10,
    );
    await File('${dir.path}/${photo.id}').writeAsString('fixture');
    final fs = FakeStorage()..directory = dir.path;
    final s = Store(fs)
      ..photoDirectory = dir.path
      ..photos = [photo]
      ..inCart = true;
    s.setAccount(
      await fs.authenticate('client@example.com', 'password1', register: true),
      transferGuestProject: true,
    );
    final order = s.createOrder();
    expect((order['photoData'] as List).length, 1);
    await s.removePhoto(0);
    expect(fs.deleted, isNot(contains(photo.id)));
    s.setSupport(
      await fs.authenticateSupport(
        'support@picpac.local',
        'test-support-password',
      ),
    );
    await expectLater(
      s.adminSetOrderStatus(order, 'Модерация'),
      throwsStateError,
    );
    await expectLater(
      s.adminModerateOrder(order, 'Одобрено', ''),
      throwsStateError,
    );
    await expectLater(fs.adminListUsers(), throwsA(isA<PlatformException>()));
    s.setAdmin(
      await fs.authenticateAdmin('admin@example.com', 'password3', setup: true),
    );
    await expectLater(
      s.adminSetOrderStatus(order, 'Производство'),
      throwsStateError,
    );
    await expectLater(
      s.adminModerateOrder(order, 'Отклонено', 'x'),
      throwsStateError,
    );
    await s.adminModerateOrder(order, 'Отклонено', 'Низкое качество');
    expect(order['moderation'], 'Отклонено');
    expect(s.notifications.first['owner'], 'client@example.com');
    await s.adminModerateOrder(order, 'Одобрено', '');
    await s.adminSetOrderStatus(order, 'Производство');
    expect(order['status'], 'Производство');
    await expectLater(
      s.adminModerateOrder(order, 'Отклонено', 'Причина'),
      throwsStateError,
    );
    await s.flush();
    final reloaded = Store(fs);
    await reloaded.load();
    expect(reloaded.orders.single['moderation'], 'Одобрено');
  });
  test('Старые заказы без материалов нельзя одобрить', () async {
    final fs = FakeStorage();
    final s = Store(fs);
    s.setAdmin(
      await fs.authenticateAdmin('admin@example.com', 'password3', setup: true),
    );
    final old = <String, dynamic>{
      'id': 'old',
      'status': 'Принят',
      'account': 'user@example.com',
    };
    s.orders.add(old);
    expect(s.orderPhotosAvailable(old), isFalse);
    await expectLater(
      s.adminModerateOrder(old, 'Одобрено', ''),
      throwsStateError,
    );
  });
  testWidgets('Сотрудник поддержки входит и отвечает в едином чате', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = FakeStorage();
    final s = Store(fs);
    s.supportMessages.addAll([
      {
        'owner': 'client@example.com',
        'order': 'PP-1',
        'sender': 'Вы',
        'text': 'Первый вопрос',
      },
      {
        'owner': 'client@example.com',
        'order': 'PP-1',
        'sender': 'Вы',
        'text': 'Второй вопрос',
      },
    ]);
    await tester.pumpWidget(MaterialApp(home: SupportStaffLogin(store: s)));
    await tester.enterText(
      find.widgetWithText(TextField, 'Email сотрудника'),
      'support@picpac.local',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Пароль'),
      'test-support-password',
    );
    await press(tester, find.text('Войти'));
    expect(s.supportEmail, 'support@picpac.local');
    await press(tester, find.text('Открыть чаты'));
    expect(find.text('Ответить'), findsOneWidget);
    expect(find.text('Второй вопрос'), findsOneWidget);
    await press(tester, find.text('Ответить'));
    expect(find.textContaining('Первый вопрос'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Ответ'),
      'Спасибо, проверяем',
    );
    await press(tester, find.text('Отправить ответ'));
    expect(s.supportMessages.last['text'], 'Спасибо, проверяем');
    expect(s.notifications.first['owner'], 'client@example.com');
  });
  testWidgets(
    'Регистрация проверяет ФИО, телефон и адрес и сохраняет профиль',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fs = FakeStorage();
      final store = Store(fs);
      await tester.pumpWidget(PicPacApp(store: store));
      await press(tester, find.text('Нет аккаунта? Зарегистрироваться'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Пароль'),
        'password123',
      );
      await press(tester, find.text('Зарегистрироваться'));
      expect(find.textContaining('Укажите фамилию и имя'), findsOneWidget);
      expect(fs.credentials, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextField, 'ФИО'),
        'Коваль Анна Сергеевна',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Телефон'), '123');
      await press(tester, find.text('Зарегистрироваться'));
      expect(find.textContaining('от 7 до 15 цифр'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Телефон'),
        '+375 29 123-45-67',
      );
      await press(tester, find.text('Зарегистрироваться'));
      expect(find.textContaining('Укажите адрес доставки'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Адрес доставки'),
        'Минск, улица Ленина 5',
      );
      await press(tester, find.text('Зарегистрироваться'));
      expect(store.accountEmail, 'new@example.com');
      final restored = Store(fs);
      await restored.load();
      expect(restored.profileName, 'Коваль Анна Сергеевна');
      expect(restored.profilePhone, '+375 29 123-45-67');
      expect(restored.profileAddress, 'Минск, улица Ленина 5');
    },
  );
  test('Настройка ролей требует подтверждения владельца', () async {
    final fs = FakeStorage();
    await expectLater(fs.setupStaff('admin', 'strong-password-123'),
        throwsA(isA<PlatformException>()));
    await expectLater(fs.setupStaff('support', 'strong-password-456'),
        throwsA(isA<PlatformException>()));
    fs.ownerConfirmed = true;
    expect(await fs.setupStaff('admin', 'strong-password-123'),
        'admin@picpac.local');
    expect(await fs.setupStaff('support', 'strong-password-456'),
        'support@picpac.local');
    await expectLater(
        fs.authenticateAdmin('admin@picpac.local', 'wrong-password',
            setup: false),
        throwsA(isA<PlatformException>()));
    expect(
        await fs.authenticateAdmin('admin@picpac.local', 'strong-password-123',
            setup: false),
        'admin@picpac.local');
    expect(
        await fs.authenticateSupport(
            'support@picpac.local', 'strong-password-456'),
        'support@picpac.local');
  });
}
