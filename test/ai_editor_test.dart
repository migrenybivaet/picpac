import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picpac_prototype/main.dart';
import 'app_test.dart' as f;

const processed = Photo(
    id: 'processed.png',
    name: 'ИИ-версия.png',
    width: 1200,
    height: 1000,
    size: 500);
void main() {
  test('Распознаёт только поддержанные команды', () {
    expect(
        parseAssistantCommand('убери фон'), AssistantCommand.removeBackground);
    expect(parseAssistantCommand('сделай синий фон'),
        AssistantCommand.blueBackground);
    expect(
        parseAssistantCommand('обрежь квадратом'), AssistantCommand.squareCrop);
    expect(parseAssistantCommand('сделай ярче'), AssistantCommand.brighter);
    expect(parseAssistantCommand('преврати человека в дракона'), isNull);
    expect(parseAssistantCommand(''), isNull);
    expect(parseAssistantCommand('не убирай фон'), isNull);
    expect(parseAssistantCommand('поверни влево'), AssistantCommand.rotateLeft);
  });
  testWidgets('Обработка создаёт копию, а оригинал остаётся в проекте',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = f.FakeStorage()..segmentResult = processed;
    final s = Store(fs)..photos = [f.one];
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AiEditor(store: s, photo: f.one))),
                    child: const Text('Открыть'))))));
    await f.press(tester, find.text('Открыть'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Команда'), 'сделай белый фон');
    await f.press(tester, find.text('Выполнить команду'));
    expect(fs.segmentationCalls, 1);
    expect(find.textContaining('Готово. Проверьте края'), findsOneWidget);
    await f.press(tester, find.text('Добавить в проект'));
    expect(s.photos.map((p) => p.id).toList(), ['one', 'processed.png']);
    await s.flush();
    final restored = Store(fs);
    await restored.load();
    expect(restored.photos.map((p) => p.id).toList(), ['one', 'processed.png']);
    expect(fs.deleted, isNot(contains('processed.png')));
  });
  testWidgets('Неизвестный запрос не отправляется на обработку',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = f.FakeStorage()..segmentResult = processed;
    final s = Store(fs)..photos = [f.one];
    await tester
        .pumpWidget(MaterialApp(home: AiEditor(store: s, photo: f.one)));
    await tester.enterText(
        find.widgetWithText(TextField, 'Команда'), 'поставь слона на луну');
    await f.press(tester, find.text('Выполнить команду'));
    expect(fs.segmentationCalls, 0);
    expect(find.textContaining('Такую команду пока не умею'), findsOneWidget);
  });
  testWidgets('Результат добавляется слоем в существующий редактор',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fs = f.FakeStorage()..segmentResult = processed;
    final s = Store(fs)..photos = [f.one];
    await tester.pumpWidget(MaterialApp(home: PhotoComposer(store: s)));
    await tester.pumpAndSettle();
    await f.press(tester, find.text('ИИ'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Команда'), 'убери фон');
    await f.press(tester, find.text('Выполнить команду'));
    await f.press(tester, find.text('Добавить в проект'));
    expect(s.photos.map((p) => p.id), contains('processed.png'));
    expect(find.text('Редактор фото'), findsWidgets);
    await f.press(tester, find.text('Сохранить'));
    final layers = s.composition!['layers'] as List;
    expect(layers.any((l) => l['imageId'] == 'processed.png'), true);
  });
}
