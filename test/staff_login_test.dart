import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_prototype/main.dart';
import 'app_test.dart' show FakeStorage, press;

class BrokenSupportStorage extends FakeStorage {
  @override
  Future<String> authenticateSupport(String email, String password) async =>
      throw PlatformException(code: 'STORAGE');
}

void main() {
  for (final role in ['admin', 'support']) {
    testWidgets('$role: подтверждение владельца, вход и повторный вход',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fs = FakeStorage()..supportConfigured = false;
      final store = Store(fs);
      Widget login() => role == 'admin'
          ? AdminLogin(store: store)
          : SupportStaffLogin(store: store);
      await tester.pumpWidget(MaterialApp(home: login()));
      await tester.pumpAndSettle();
      expect(find.textContaining('доступ ещё не настроен'), findsOneWidget);
      final email =
          role == 'admin' ? 'admin@picpac.local' : 'support@picpac.local';
      expect(find.text(email), findsOneWidget);
      await press(tester, find.text('Создать или восстановить доступ'));
      await tester.enterText(find.widgetWithText(TextField, 'Новый пароль'),
          'different-password-2026');
      await tester.enterText(find.widgetWithText(TextField, 'Повторите пароль'),
          'different-password-2026');
      await press(tester, find.text('Подтвердить на телефоне'));
      expect(
          find.textContaining('подтверждение владельца отменено',
              findRichText: true),
          findsNothing); // message starts with uppercase
      expect(find.textContaining('Подтверждение владельца отменено'),
          findsOneWidget);
      expect(fs.adminSignedIn, isNull);
      expect(fs.supportSignedIn, isNull);
      fs.ownerConfirmed = true;
      await press(tester, find.text('Подтвердить на телефоне'));
      expect(role == 'admin' ? store.adminEmail : store.supportEmail, email);
      expect(find.text(role == 'admin' ? 'Панель управления' : 'Рабочее место'),
          findsOneWidget);
      if (role == 'admin') {
        await fs.adminLogout();
        store.setAdmin(null);
      } else {
        await fs.supportLogout();
        store.setSupport(null);
      }
      await tester
          .pumpWidget(MaterialApp(key: const ValueKey('new'), home: login()));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Пароль'), 'wrong-password-2026');
      await press(tester, find.text('Войти'));
      expect(find.textContaining('Неверный логин или пароль'), findsOneWidget);
      expect(fs.adminSignedIn, isNull);
      expect(fs.supportSignedIn, isNull);
      await tester.enterText(
          find.widgetWithText(TextField, 'Пароль'), 'different-password-2026');
      await press(tester, find.text('Войти'));
      expect(role == 'admin' ? store.adminEmail : store.supportEmail, email);
      expect(find.text(role == 'admin' ? 'Панель управления' : 'Рабочее место'),
          findsOneWidget);
    });
  }

  testWidgets('техническая ошибка поддержки не выдаётся за неверный пароль',
      (tester) async {
    final store = Store(BrokenSupportStorage());
    await tester.pumpWidget(MaterialApp(home: SupportStaffLogin(store: store)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Пароль'), 'some-long-password');
    await press(tester, find.text('Войти'));
    expect(find.textContaining('Ошибка входа или хранилища'), findsOneWidget);
    expect(find.textContaining('Неверный логин или пароль'), findsNothing);
  });

  testWidgets('гость не может открыть панели сотрудников', (tester) async {
    final store = Store(FakeStorage());
    await tester.pumpWidget(MaterialApp(home: AdminPanel(store: store)));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Доступ только для сотрудников'), findsOneWidget);
    expect(find.text('Панель управления'), findsNothing);
    await tester.pumpWidget(MaterialApp(home: SupportStaffPanel(store: store)));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Доступ только для сотрудников'), findsOneWidget);
    expect(find.text('Рабочее место'), findsNothing);
  });

  test('AndroidStorage использует правильные методы и роли канала', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidStorage.channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'staffAccessState':
          return 'missing';
        case 'setupStaff':
          return '${call.arguments['role']}@picpac.local';
        case 'adminLogin':
          return 'admin@picpac.local';
        case 'supportLogin':
          return 'support@picpac.local';
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidStorage.channel, null));
    final native = AndroidStorage();
    expect(await native.staffAccessState('admin'), 'missing');
    expect(await native.setupStaff('admin', 'long-password-123'),
        'admin@picpac.local');
    expect(
        await native.authenticateAdmin(
            'admin@picpac.local', 'long-password-123',
            setup: false),
        'admin@picpac.local');
    expect(await native.setupStaff('support', 'long-password-456'),
        'support@picpac.local');
    expect(
        await native.authenticateSupport(
            'support@picpac.local', 'long-password-456'),
        'support@picpac.local');
    expect(calls.map((c) => c.method).toList(), [
      'staffAccessState',
      'setupStaff',
      'adminLogin',
      'setupStaff',
      'supportLogin'
    ]);
    expect(calls[1].arguments['role'], 'admin');
    expect(calls[3].arguments['role'], 'support');
  });
}
