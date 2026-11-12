import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_prototype/main.dart';
import 'app_test.dart' as f;

void sizePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test(
      'Разные макеты страниц, порядок и размеры сохраняются в проекте и заказе',
      () async {
    final fs = f.FakeStorage();
    final s = Store(fs)
      ..photos = [
        for (var i = 0; i < 25; i++)
          Photo(id: 'p$i', name: '$i.jpg', width: 2400, height: 2400, size: 1)
      ];
    s.formatIndex = 1;
    expect(s.format, '21 × 30 см');
    expect(s.bookPageAspect, closeTo(.7, .001));
    expect(s.spreadCount, 10);
    s.setBookPageLayout(0, 'pair');
    s.setBookPageLayout(1, 'grid');
    s.setBookPageLayout(2, 'frame');
    s.setBookPageLayout(200, 'grid');
    expect(s.bookPageLayouts.containsKey(200), isFalse);
    expect(s.bookPagePhotoStart(0), 0);
    expect(s.bookPagePhotoStart(1), 2);
    expect(s.bookPagePhotoStart(2), 6);
    expect(s.unplacedBookPhotos, 1);
    await s.flush();
    final restored = Store(fs);
    await restored.load();
    expect(restored.bookPageLayouts, {0: 'pair', 1: 'grid', 2: 'frame'});
    expect(restored.format, '21 × 30 см');
    final oldId = restored.currentProjectId;
    restored.startNewProject();
    expect(restored.bookPageLayouts, isEmpty);
    expect(restored.photos, isEmpty);
    restored.restoreProject(oldId);
    expect(restored.bookPageLayouts, {0: 'pair', 1: 'grid', 2: 'frame'});
    restored.accountEmail = 'user@example.com';
    restored.inCart = true;
    final order = restored.createOrder();
    expect(order['bookPageLayouts']['0'], 'pair');
    expect(order['bookPageLayouts']['1'], 'grid');
    expect(order['unplacedPhotos'], 1);
  });

  test('Размеры книги и количество страниц по продуктам', () {
    final s = Store(f.FakeStorage());
    expect(s.formats, containsAll(['20 × 20 см', '21 × 30 см', '25 × 25 см']));
    s.productIndex = 2;
    expect(s.spreadCount, 12);
    expect(s.bookPageCount, 24);
    expect(s.formats, containsAll(['20 × 20 см', '21 × 30 см', '25 × 25 см']));
    s.productIndex = 3;
    expect(s.spreadCount, 5);
  });

  test('Макеты не переносятся между аккаунтами и новым проектом', () async {
    final fs = f.FakeStorage();
    final s = Store(fs);
    s.setAccount(await fs.authenticate('first@example.com', 'password1',
        register: true));
    s.photos = [f.one];
    s.setBookPageLayout(0, 'grid');
    s.setAccount(await fs.authenticate('second@example.com', 'password2',
        register: true));
    expect(s.bookPageLayouts, isEmpty);
    expect(s.photos, isEmpty);
    s.photos = [f.two];
    s.setBookPageLayout(1, 'pair');
    s.setAccount(await fs.authenticate('first@example.com', 'password1',
        register: false));
    expect(s.bookPageLayouts, {0: 'grid'});
    expect(s.photos.single.id, f.one.id);
    await s.flush();
    final restored = Store(fs);
    await restored.load();
    expect(restored.bookPageLayouts, {0: 'grid'});
  });

  testWidgets('Проверка книги предупреждает о пустых ячейках', (tester) async {
    sizePhone(tester);
    final s = Store(f.FakeStorage())..photos = [f.one];
    await tester.pumpWidget(MaterialApp(home: CheckPage(store: s)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Пустых ячеек в книге: 19'), findsOneWidget);
  });

  testWidgets('В ИИ-редакторе разные страницы получают независимые макеты',
      (tester) async {
    sizePhone(tester);
    final s = Store(f.FakeStorage())..photos = [f.one, f.two];
    await tester
        .pumpWidget(MaterialApp(home: AiEditor(store: s, photo: f.one)));
    await f.press(tester, find.text('Макеты страниц книги'));
    expect(find.text('Разворот 1 из 10'), findsOneWidget);
    await f.press(tester, find.text('Макет слева'));
    await f.press(tester, find.text('Два снимка'));
    await f.press(tester, find.text('Готово'));
    await f.press(tester, find.text('Макет справа'));
    await f.press(tester, find.text('Коллаж'));
    await f.press(tester, find.text('Готово'));
    expect(s.layoutForBookPage(0).id, 'pair');
    expect(s.layoutForBookPage(1).id, 'grid');
    expect(s.layoutForBookPage(2).id, 'single');
    await f.press(tester, find.byTooltip('Следующий разворот'));
    expect(find.text('Разворот 2 из 10'), findsOneWidget);
    await f.press(tester, find.text('Макет слева'));
    await f.press(tester, find.text('С рамкой'));
    await f.press(tester, find.text('Готово'));
    expect(s.layoutForBookPage(2).id, 'frame');
    expect(s.layoutForBookPage(0).id, 'pair');
    await f.press(tester, find.text('Готово'));
    expect(find.text('Помощник для фото'), findsWidgets);
  });

  testWidgets('При входе показывается приветствие с именем и затем каталог',
      (tester) async {
    sizePhone(tester);
    final fs = f.FakeStorage();
    await fs.authenticate('name@example.com', 'password123', register: true);
    final s = Store(fs);
    s.profiles['name@example.com'] = {'name': 'Анна Иванова'};
    await tester.pumpWidget(MaterialApp(home: AuthPage(store: s)));
    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'name@example.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Пароль'), 'password123');
    await tester.tap(find.text('Войти'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Добро пожаловать,'), findsOneWidget);
    expect(find.textContaining('Анна Иванова'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(MainTabs), findsOneWidget);
  });

  testWidgets(
      'Чат показывает сообщения пользователя и поддержки в одном диалоге',
      (tester) async {
    sizePhone(tester);
    final fs = f.FakeStorage();
    final s = Store(fs);
    s.accountEmail = 'one@example.com';
    s.supportMessages.addAll([
      {
        'owner': 'one@example.com',
        'order': 'PP-1',
        'sender': 'Поддержка',
        'text': 'Поможем с заказом',
        'time': '2026-11-11T12:00:00'
      },
      {
        'owner': 'other@example.com',
        'order': 'PP-1',
        'sender': 'Поддержка',
        'text': 'Чужой ответ',
        'time': '2026-11-11T12:00:00'
      },
    ]);
    await tester
        .pumpWidget(MaterialApp(home: Support(store: s, orderId: 'PP-1')));
    await tester.pumpAndSettle();
    expect(find.text('Поможем с заказом'), findsOneWidget);
    expect(find.text('Чужой ответ'), findsNothing);
    await tester.enterText(
        find.widgetWithText(TextField, 'Сообщение'), 'Спасибо за помощь');
    await f.press(tester, find.text('Отправить'));
    expect(find.text('Спасибо за помощь'), findsOneWidget);
    expect(s.supportMessages.last['owner'], 'one@example.com');
    expect(s.supportMessages.last['order'], 'PP-1');
    await s.flush();
    final restored = Store(fs);
    await restored.load();
    expect(restored.supportMessages.last['text'], 'Спасибо за помощь');
  });
}
