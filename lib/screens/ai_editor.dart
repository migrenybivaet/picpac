part of '../main.dart';

/// On-device portrait model + an explicitly limited rule-based command parser.
class AiEditor extends StatefulWidget {
  final Store store;
  final Photo photo;
  const AiEditor({super.key, required this.store, required this.photo});
  @override
  State<AiEditor> createState() => _AiEditorState();
}

class _AiEditorState extends State<AiEditor> {
  late Photo draft;
  final text = TextEditingController();
  final Set<String> temporary = {};
  String? backgroundId;
  bool busy = false;
  String status = 'Напишите команду или выберите действие ниже.';
  @override
  void initState() {
    super.initState();
    draft = widget.photo;
  }

  @override
  void dispose() {
    text.dispose();
    for (final id in temporary) {
      unawaited(widget.store.storage.delete(id).catchError((_) {}));
    }
    super.dispose();
  }

  Photo withFile(Photo file) => Photo(
        id: file.id,
        name: file.name,
        width: file.width,
        height: file.height,
        size: file.size,
        turns: draft.turns,
        crop: draft.crop,
        frame: draft.frame,
        effect: draft.effect,
        frameVisible: draft.frameVisible,
        effectVisible: draft.effectVisible,
        positionX: draft.positionX,
        positionY: draft.positionY,
        brightness: draft.brightness,
      );
  Future<void> chooseBackground() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final picked = await widget.store.storage.pick();
      if (picked.files.isEmpty) {
        if (mounted)
          setState(() => status = picked.errors.isEmpty
              ? 'Выбор фона отменён.'
              : picked.errors.first);
        return;
      }
      if (!mounted) {
        for (final p in picked.files) {
          await widget.store.storage.delete(p.id);
        }
        return;
      }
      for (final p in picked.files) {
        temporary.add(p.id);
      }
      backgroundId = picked.files.first.id;
      if (mounted)
        setState(
            () => status = 'Фон выбран. Нажмите «Применить выбранный фон».');
    } catch (_) {
      if (mounted) setState(() => status = 'Не удалось открыть галерею.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> segment({int? color, bool custom = false}) async {
    if (busy) return;
    if (custom && backgroundId == null) {
      setState(() => status = 'Сначала выберите фото для фона.');
      return;
    }
    setState(() {
      busy = true;
      status = 'Выделяем человека на телефоне…';
    });
    try {
      // Segment the original source each time; never process an already cut-out result.
      final processed = await widget.store.storage.segmentPortrait(
          widget.photo.id,
          backgroundId: custom ? backgroundId : null,
          color: color);
      if (!mounted) {
        await widget.store.storage.delete(processed.id);
        return;
      }
      final oldId = draft.id;
      setState(() {
        draft = withFile(processed);
        temporary.add(processed.id);
        status = 'Готово. Проверьте края и нажмите «Добавить в проект».';
      });
      if (temporary.remove(oldId)) await widget.store.storage.delete(oldId);
    } on PlatformException catch (e) {
      if (mounted)
        setState(() => status = e.message ?? 'Не удалось обработать портрет.');
    } catch (_) {
      if (mounted) setState(() => status = 'Не удалось обработать портрет.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> runCommand() async {
    final command = parseAssistantCommand(text.text);
    if (command == null) {
      setState(() => status =
          'Такую команду пока не умею. Попробуйте: «убери фон», «синий фон», «обрежь квадратом» или «сделай ярче».');
      return;
    }
    switch (command) {
      case AssistantCommand.removeBackground:
        await segment();
        return;
      case AssistantCommand.whiteBackground:
        await segment(color: 0xffffffff);
        return;
      case AssistantCommand.blackBackground:
        await segment(color: 0xff202020);
        return;
      case AssistantCommand.blueBackground:
        await segment(color: 0xff8eb8d7);
        return;
      case AssistantCommand.greenBackground:
        await segment(color: 0xffa6c9b0);
        return;
      case AssistantCommand.chooseBackground:
        setState(() => status =
            'Генерации по описанию пока нет. Выберите готовую фотографию для фона.');
        await chooseBackground();
        return;
      default:
        break;
    }
    final oldId = draft.id;
    setState(() {
      draft = switch (command) {
        AssistantCommand.squareCrop => draft.copyWith(crop: 'square'),
        AssistantCommand.landscapeCrop => draft.copyWith(crop: 'landscape'),
        AssistantCommand.portraitCrop => draft.copyWith(crop: 'portrait'),
        AssistantCommand.rotateRight =>
          draft.copyWith(turns: (draft.turns + 1) % 4),
        AssistantCommand.rotateLeft =>
          draft.copyWith(turns: (draft.turns + 3) % 4),
        AssistantCommand.mono =>
          draft.copyWith(effect: 'mono', effectVisible: true),
        AssistantCommand.warm =>
          draft.copyWith(effect: 'warm', effectVisible: true),
        AssistantCommand.brighter =>
          draft.copyWith(brightness: (draft.brightness + .1).clamp(-.3, .3)),
        AssistantCommand.reset => widget.photo,
        _ => draft,
      };
      status = command == AssistantCommand.squareCrop
          ? 'Выбрано кадрирование 1:1. Формат можно изменить в редакторе.'
          : 'Действие применено к предпросмотру.';
    });
    if (command == AssistantCommand.reset && temporary.remove(oldId))
      await widget.store.storage.delete(oldId);
  }

  Future<void> save() async {
    if (busy) return;
    final s = widget.store;
    final index = s.photos.indexWhere((p) => p.id == widget.photo.id);
    if (index < 0) {
      setState(() => status = 'Исходное фото больше не найдено в проекте.');
      return;
    }
    setState(() => busy = true);
    final before = List<Photo>.from(s.photos);
    final priorComposition = s.composition == null
        ? null
        : jsonDecode(jsonEncode(s.composition)) as Map<String, dynamic>;
    final isNew = draft.id != widget.photo.id;
    if (isNew) {
      // Keep the original in the project and add the edited PNG next to it.
      s.photos.insert(index + 1, draft);
      if (s.composition != null) {
        final data = Map<String, dynamic>.from(s.composition!);
        final layers = (data['layers'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        layers.add(
            Layer(id: 'photo-${draft.id}', imageId: draft.id, visible: false)
                .toMap());
        data['layers'] = layers;
        data.remove('preview');
        s.composition = data;
      }
    } else {
      s.photos[index] = draft;
      s.invalidateCompositionPreview();
    }
    s.changed();
    await s.flush();
    if (s.saveFailed) {
      s.photos = before;
      s.composition = priorComposition;
      s.changed();
      if (mounted)
        setState(() {
          busy = false;
          status = 'Не удалось сохранить проект. Попробуйте ещё раз.';
        });
      return;
    }
    if (isNew) temporary.remove(draft.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext c) => PageShell(
        store: widget.store,
        title: 'Помощник для фото',
        bottom: Primary('Добавить в проект', onTap: busy ? null : save),
        child: scroll([
          h1('Помощник для фото'),
          if (widget.store.isBook) ...[
            space(10),
            Primary('Макеты страниц книги',
                outline: true,
                onTap: busy
                    ? null
                    : () => open(c, BookSpreadsPage(store: widget.store))),
          ],
          space(6),
          hint(
              'Выделение человека выполняется моделью на телефоне. Команды распознаются по ключевым словам; генерации картинок по тексту пока нет.'),
          space(12),
          Container(
              height: 270,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: peach, borderRadius: BorderRadius.circular(16)),
              child: Center(
                  child: PhotoPreview(store: widget.store, photo: draft))),
          space(10),
          Text(status, style: const TextStyle(color: ink)),
          space(12),
          TextField(
              controller: text,
              maxLength: 300,
              maxLines: 2,
              enabled: !busy,
              decoration: const InputDecoration(
                  labelText: 'Команда',
                  hintText: 'Например: убери фон или сделай ярче')),
          Primary('Выполнить команду',
              outline: true, onTap: busy ? null : runCommand),
          space(14),
          section('Быстрые действия'),
          space(8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            ActionChip(
                label: const Text('Квадрат'),
                onPressed: busy
                    ? null
                    : () {
                        text.text = 'обрежь квадратом';
                        runCommand();
                      }),
            ActionChip(
                label: const Text('Ярче'),
                onPressed: busy
                    ? null
                    : () {
                        text.text = 'сделай ярче';
                        runCommand();
                      }),
            ActionChip(
                label: const Text('Чёрно-белое'),
                onPressed: busy
                    ? null
                    : () {
                        text.text = 'черно-белое';
                        runCommand();
                      }),
            ActionChip(
                label: const Text('Повернуть'),
                onPressed: busy
                    ? null
                    : () {
                        text.text = 'поверни вправо';
                        runCommand();
                      }),
            ActionChip(
                label: const Text('Удалить фон'),
                onPressed: busy ? null : () => segment()),
            ActionChip(
                label: const Text('Белый фон'),
                onPressed: busy ? null : () => segment(color: 0xffffffff)),
            ActionChip(
                label: const Text('Синий фон'),
                onPressed: busy ? null : () => segment(color: 0xff8eb8d7)),
            ActionChip(
                label: const Text('Зелёный фон'),
                onPressed: busy ? null : () => segment(color: 0xffa6c9b0)),
            ActionChip(
                label: const Text('Выбрать свой фон'),
                onPressed: busy ? null : chooseBackground),
            ActionChip(
                label: const Text('Применить выбранный фон'),
                onPressed: busy || backgroundId == null
                    ? null
                    : () => segment(custom: true)),
          ]),
          space(12),
          hint(
              'Модель предназначена для фотографий людей. Края могут быть неточными. Результат обработки ограничен примерно 1600 px по большей стороне и не предназначен для качественной печати.'),
          space(8),
          hint(
              'После обработки создаётся отдельная копия; исходная фотография остаётся в проекте. Фото не отправляются в сеть.'),
        ]),
      );
}
