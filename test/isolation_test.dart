import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:picpac_prototype/main.dart';
import 'app_test.dart' as f;

void main() {
  test(
      'Аккаунты и гостевой проект изолированы после переключения и перезапуска',
      () async {
    final fs = f.FakeStorage();
    final s = Store(fs);
    await s.load();
    s.photos = [f.one];
    s.inCart = true;
    s.changed();
    s.setAccount(
        await fs.authenticate('a@example.com', 'password1', register: true));
    expect(s.photos, isEmpty);
    expect(s.inCart, isFalse);
    s.photos = [f.two];
    s.changed();
    s.startNewProject();
    s.photos = [f.one];
    s.changed();
    s.setAccount(
        await fs.authenticate('b@example.com', 'password2', register: true));
    expect(s.photos, isEmpty);
    expect(s.savedProjects, isEmpty);
    s.photos = [f.one];
    s.changed();
    await s.flush();
    final reloaded = Store(fs);
    await reloaded.load();
    expect(reloaded.photos.single.name, f.one.name);
    reloaded.setAccount(
        await fs.authenticate('a@example.com', 'password1', register: false));
    expect(reloaded.photos.single.name, f.one.name);
    expect(reloaded.savedProjects.single['photos'][0]['name'], f.two.name);
    reloaded.setAccount(null);
    expect(reloaded.photos.single.name, f.one.name);
  });
  test('Гостевой проект переносится только с разрешения', () async {
    final fs = f.FakeStorage();
    final s = Store(fs);
    await s.load();
    s.photos = [f.one];
    s.inCart = true;
    s.setAccount(
        await fs.authenticate('a@example.com', 'password1', register: true),
        transferGuestProject: true);
    expect(s.photos.single.name, f.one.name);
    expect(s.inCart, true);
    s.setAccount(null);
    expect(s.photos, isEmpty);
  });
  test('Старые общие проекты не выдаются автоматически', () async {
    final fs = f.FakeStorage()
      ..data = jsonEncode({
        'photos': [f.one.toMap()]
      });
    final s = Store(fs);
    await s.load();
    expect(s.photos, isEmpty);
    expect(s.unassignedLegacyDraft, isNotNull);
    s.setAccount(
        await fs.authenticate('a@example.com', 'password1', register: true));
    await expectLater(s.claimLegacyDrafts(), throwsStateError);
    expect(s.savedProjects, isEmpty);
    fs.ownerConfirmed = true;
    await s.claimLegacyDrafts();
    expect(s.savedProjects.single['photos'][0]['name'], f.one.name);
    expect(s.unassignedLegacyDraft, isNull);
  });
  test(
      'После удаления и повторной регистрации старые проекты и заказы недоступны',
      () async {
    final fs = f.FakeStorage();
    final s = Store(fs);
    await s.load();
    s.setAccount(
        await fs.authenticate('a@example.com', 'password1', register: true));
    s.photos = [f.one];
    s.inCart = true;
    s.changed();
    s.createOrder();
    await s.flush();
    await s.deleteCurrentAccountData();
    s.setAccount(
        await fs.authenticate('a@example.com', 'password2', register: true));
    expect(s.photos, isEmpty);
    expect(s.savedProjects, isEmpty);
    expect(s.myOrders, isEmpty);
    final restored = Store(fs);
    await s.flush();
    await restored.load();
    expect(restored.photos, isEmpty);
    expect(restored.myOrders, isEmpty);
  });
  test('Карта качества учитывает ориентацию и физический размер', () {
    expect(estimatePrintDpi(1200, 1800, 10, 15), closeTo(304.8, 0.01));
    expect(estimatePrintDpi(1800, 1200, 10, 15), closeTo(304.8, 0.01));
    expect(estimatePrintDpi(1200, 1800, 20, 30), closeTo(152.4, 0.01));
    expect(qualityLabel(152), 'Может быть нечётким');
    expect(estimatePrintDpi(0, 1800, 10, 15), 0);
  });
  test('Десять фото и их порядок сохраняются для одного владельца', () async {
    final fs = f.FakeStorage();
    final s = Store(fs);
    await s.load();
    s.setAccount(
        await fs.authenticate('a@example.com', 'password1', register: true));
    s.photos = List.generate(
        10,
        (i) => Photo(
            id: 'photo-$i',
            name: '$i.jpg',
            width: 2000,
            height: 2000,
            size: 100));
    s.movePhoto(0, 10);
    s.changed();
    await s.flush();
    final restored = Store(fs);
    await restored.load();
    expect(restored.photos.length, 10);
    expect(restored.photos.last.id, 'photo-0');
    restored.setAccount(
        await fs.authenticate('b@example.com', 'password2', register: true));
    expect(restored.photos, isEmpty);
    expect(restored.savedProjects, isEmpty);
  });
  test('Без авторизации ролей нет доступа к административным данным', () async {
    final fs = f.FakeStorage();
    final s = Store(fs);
    await s.load();
    await expectLater(fs.adminListUsers(), throwsA(isA<Exception>()));
    await expectLater(
        s.adminSetOrderStatus(<String, dynamic>{}, 'Принят'), throwsStateError);
  });
  testWidgets('Гость и подменённая роль не открывают админ-панель',
      (tester) async {
    final fs = f.FakeStorage();
    final s = Store(fs);
    await s.load();
    await tester.pumpWidget(MaterialApp(home: AdminPanel(store: s)));
    await tester.pumpAndSettle();
    expect(find.text('Панель управления'), findsNothing);
    expect(
        find.textContaining('Доступ только для сотрудников'), findsOneWidget);
    s.setAdmin('admin@picpac.local');
    await tester.pumpAndSettle();
    expect(find.text('Панель управления'), findsNothing);
    expect(find.textContaining('Доступ запрещён'), findsOneWidget);
  });
}
