part of '../main.dart';

class PhotoPreview extends StatelessWidget {
  final Store store;
  final Photo photo;
  final int decodeWidth;
  const PhotoPreview({
    super.key,
    required this.store,
    required this.photo,
    this.decodeWidth = 1600,
  });
  @override
  Widget build(BuildContext context) {
    final file = store.photoFile(photo);
    final offset = photo.brightness * 255;
    Widget image = file == null
        ? SizedBox(
            width: photo.width.toDouble(),
            height: photo.height.toDouble(),
            child: const ColoredBox(
              color: Color(0xffe3e8e6),
              child: Center(
                child: Icon(Icons.photo_outlined, color: secondary),
              ),
            ),
          )
        : Image.file(
            file,
            key: ValueKey('${photo.id}-${photo.turns}-${photo.crop}'),
            width: photo.width.toDouble(),
            height: photo.height.toDouble(),
            fit: BoxFit.fill,
            cacheWidth: photo.width > decodeWidth ? decodeWidth : null,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Color(0xffe3e8e6),
              child: Center(
                child: Icon(Icons.broken_image_outlined, color: secondary),
              ),
            ),
          );
    Widget picture = FittedBox(
      fit: BoxFit.cover,
      alignment: Alignment(photo.positionX, photo.positionY),
      clipBehavior: Clip.hardEdge,
      child: RotatedBox(quarterTurns: photo.turns, child: image),
    );
    if (photo.effectVisible && photo.effect != 'none') {
      final matrix = photo.effect == 'mono'
          ? <double>[
              .2126, .7152, .0722, 0, 0,
              .2126, .7152, .0722, 0, 0,
              .2126, .7152, .0722, 0, 0,
              0, 0, 0, 1, 0,
            ]
          : <double>[
              1, 0, 0, 0, 18,
              0, 1, 0, 0, 7,
              0, 0, 1, 0, -12,
              0, 0, 0, 1, 0,
            ];
      picture = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: picture,
      );
    }
    if (offset != 0) {
      picture = ColorFiltered(
      colorFilter: ColorFilter.matrix([
        1, 0, 0, 0, offset,
        0, 1, 0, 0, offset,
        0, 0, 1, 0, offset,
        0, 0, 0, 1, 0,
      ]),
      child: picture,
    );
    }
    final hasFrame = photo.frameVisible && photo.frame != 'none';
    return AspectRatio(
      aspectRatio: photo.aspectRatio.clamp(.1, 10),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.white, child: picture),
            if (hasFrame)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: photo.frame == 'dark' ? ink : Colors.white, width: 8),
                      left: BorderSide(color: photo.frame == 'dark' ? ink : Colors.white, width: 8),
                      right: BorderSide(color: photo.frame == 'dark' ? ink : Colors.white, width: 8),
                      bottom: BorderSide(color: photo.frame == 'dark' ? ink : Colors.white, width: photo.frame == 'film' ? 22 : 8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LayoutPreview extends StatelessWidget {
  final Store store;
  final BookLayout layout;
  final int start;
  final double aspectRatio;
  const LayoutPreview({
    super.key,
    required this.store,
    required this.layout,
    this.start = 0,
    this.aspectRatio = 1,
  });
  @override
  Widget build(BuildContext c) {
    final rows = (layout.slots / layout.columns).ceil();
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        padding: EdgeInsets.all(layout.inset + store.layoutMargin),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: layout.slots,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: layout.columns,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: rows / layout.columns * aspectRatio,
          ),
          itemBuilder: (c, i) {
            final position = start + i;
            final hasPhoto = position < store.photos.length;
            
            Widget cellContent = hasPhoto
                ? Center(child: PhotoPreview(store: store, photo: store.photos[position], decodeWidth: 800))
                : const Center(child: Icon(Icons.add_photo_alternate_outlined, color: secondary));

            Widget targetZone = DragTarget<int>(
              onWillAccept: (fromIndex) => fromIndex != position,
              onAccept: (fromIndex) {
                if (fromIndex < store.photos.length) {
                  final temp = store.photos.removeAt(fromIndex);
                  if (position < store.photos.length) {
                     final targetPhoto = store.photos.removeAt(position < fromIndex ? position : position - 1);
                     store.photos.insert(position < fromIndex ? position : position - 1, temp);
                     store.photos.insert(fromIndex > position ? fromIndex : fromIndex + 1, targetPhoto);
                  } else {
                     store.photos.add(temp);
                  }
                  store.changed();
                }
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: candidateData.isNotEmpty ? red : Colors.transparent, width: 2),
                    color: candidateData.isNotEmpty ? pink.withOpacity(0.3) : null,
                  ),
                  child: cellContent,
                );
              },
            );

            Widget draggableItem = hasPhoto 
              ? LongPressDraggable<int>(
                  data: position,
                  feedback: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 80, height: 80,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: PhotoPreview(store: store, photo: store.photos[position], decodeWidth: 200),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.3, child: cellContent),
                  child: targetZone,
                )
              : targetZone;

            return ClipRect(
              child: ColoredBox(
                color: const Color(0xffe8eae7),
                child: draggableItem,
              ),
            );
          },
        ),
      ),
    );
  }
}

class TemplatesPage extends StatelessWidget {
  final Store store;
  final int? bookPageIndex;
  const TemplatesPage({super.key, required this.store, this.bookPageIndex});
  @override
  Widget build(BuildContext c) => StoreBuilder(
        animation: store,
        builder: (c, _) => PageShell(
          store: store,
          title: 'Выбор макета',
          bottom: Primary('Готово', onTap: () => Navigator.pop(c)),
          child: scroll([
            h1('Выберите макет'),
            space(8),
            hint(bookPageIndex == null
                ? 'Базовый макет для страниц без индивидуального выбора.'
                : 'Макет только для страницы ${(bookPageIndex! + 1)}.'),
            space(20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: layouts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: .72,
              ),
              itemBuilder: (c, i) {
                final l = layouts[i],
                    selected = l.id == (bookPageIndex == null ? store.layoutId : store.layoutForBookPage(bookPageIndex!).id);
                return InkWell(
                  onTap: () {
                    if (bookPageIndex == null) {
                      store.layoutId = l.id;
                      store.changed();
                    } else {
                      store.setBookPageLayout(bookPageIndex!, l.id);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? red : border, width: selected ? 2 : 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Center(
                            child: LayoutPreview(
                                store: store,
                                layout: l,
                                start: bookPageIndex == null ? 0 : store.bookPagePhotoStart(bookPageIndex!)),
                          ),
                        ),
                        space(7),
                        Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(l.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: secondary, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ]),
        ),
      );
}

class PhotoEditor extends StatefulWidget {
  final Store store;
  final Photo photo;
  const PhotoEditor({super.key, required this.store, required this.photo});
  @override
  State<PhotoEditor> createState() => _PhotoEditorState();
}

class _PhotoEditorState extends State<PhotoEditor> {
  late Photo current;
  String tool = 'Кадр';
  @override
  void initState() {
    super.initState();
    current = widget.photo;
  }

  void save() {
    final i = widget.store.photos.indexWhere((p) => p.id == current.id);
    if (i >= 0) {
      widget.store.photos[i] = current;
      widget.store.invalidateCompositionPreview();
      widget.store.changed();
    }
    Navigator.pop(context);
  }

  Photo get original => current.copyWith(
        turns: 0, crop: 'original', positionX: 0, positionY: 0, brightness: 0, frame: 'none', effect: 'none',
      );
      
  Widget toolButton(String name, IconData icon) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: tool == name ? pink : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => tool = name),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: tool == name ? red : ink),
                const SizedBox(height: 3),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 10,
                    color: tool == name ? ink : secondary,
                    fontWeight: tool == name ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      
  @override
  Widget build(BuildContext c) => PageShell(
        store: widget.store,
        title: 'Редактор фото',
        bottom: Primary('Сохранить', onTap: save),
        child: scroll([
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .9),
                    border: Border.all(color: Colors.white.withValues(alpha: .8)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      toolButton('Кадр', Icons.crop),
                      toolButton('Макеты', Icons.dashboard_outlined),
                      toolButton('Рамки', Icons.crop_original),
                      toolButton('Эффекты', Icons.auto_fix_high_outlined),
                      toolButton('Слои', Icons.layers_outlined),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 245,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: blueGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x14cfdde7), blurRadius: 20, offset: Offset(0, 8))],
                  ),
                  child: Center(
                    child: PhotoPreview(store: widget.store, photo: current),
                  ),
                ),
              ),
            ],
          ),
          space(10),
          Row(
            children: [
              const Text('Исходное фото', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              SizedBox(
                width: 60, height: 50,
                child: Center(child: PhotoPreview(store: widget.store, photo: original)),
              ),
            ],
          ),
          const Divider(),
          Primary('ИИ-помощник', outline: true, onTap: () async {
            final applied = await open<bool>(c, AiEditor(store: widget.store, photo: current));
            if (applied == true && c.mounted) Navigator.pop(c);
          }),
          space(8),
          section(tool),
          space(8),
          if (tool == 'Кадр') ...[
            Row(
              children: [
                const Expanded(child: Text('Поворот')),
                IconButton(onPressed: () => setState(() => current = current.copyWith(turns: (current.turns + 3) % 4)), icon: const Icon(Icons.rotate_left)),
                IconButton(onPressed: () => setState(() => current = current.copyWith(turns: (current.turns + 1) % 4)), icon: const Icon(Icons.rotate_right)),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final option in const [('original', 'Оригинал'), ('square', '1:1'), ('landscape', '4:3'), ('portrait', '3:4')])
                  ChoiceChip(
                    label: Text(option.$2),
                    selected: current.crop == option.$1,
                    onSelected: (_) => setState(() => current = current.copyWith(crop: option.$1)),
                  ),
              ],
            ),
          ],
          if (tool == 'Макеты') ...[
            hint(widget.store.isBook ? 'Выберите готовое расположение снимков для страниц книги.' : 'Макеты страниц доступны для фотокниг.'),
            space(8),
            if (widget.store.isBook) Primary('Выбрать макет', outline: true, onTap: () => open(c, TemplatesPage(store: widget.store))),
          ],
          if (tool == 'Рамки') ...[
            hint('Рамка накладывается поверх фотографии.'),
            Wrap(
              spacing: 8,
              children: [
                for (final item in const [('none', 'Без рамки'), ('white', 'Белая'), ('dark', 'Тёмная'), ('film', 'Полароид')])
                  ChoiceChip(
                    label: Text(item.$2),
                    selected: current.frame == item.$1,
                    onSelected: (_) => setState(() => current = current.copyWith(frame: item.$1, frameVisible: true)),
                  ),
              ],
            ),
          ],
          if (tool == 'Эффекты') ...[
            Wrap(
              spacing: 8,
              children: [
                for (final item in const [('none', 'Без эффекта'), ('mono', 'Чёрно-белый'), ('warm', 'Тёплый')])
                  ChoiceChip(
                    label: Text(item.$2),
                    selected: current.effect == item.$1,
                    onSelected: (_) => setState(() => current = current.copyWith(effect: item.$1, effectVisible: true)),
                  ),
              ],
            ),
            space(8),
            const Text('Яркость'),
            Slider(
              value: current.brightness,
              min: -.3, max: .3, divisions: 12,
              onChanged: (v) => setState(() => current = current.copyWith(brightness: v)),
            ),
          ],
          if (tool == 'Слои') ...[
            const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.photo_outlined), title: Text('Фотография'), subtitle: Text('Основной слой')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Рамка'),
              subtitle: Text(current.frame == 'none' ? 'Не выбрана' : 'Поверх фото'),
              value: current.frameVisible && current.frame != 'none',
              onChanged: current.frame == 'none' ? null : (v) => setState(() => current = current.copyWith(frameVisible: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Цветовой эффект'),
              subtitle: Text(current.effect == 'none' ? 'Не выбран' : 'Применяется к фотографии'),
              value: current.effectVisible && current.effect != 'none',
              onChanged: current.effect == 'none' ? null : (v) => setState(() => current = current.copyWith(effectVisible: v)),
            ),
          ],
          space(8),
          TextButton(
            onPressed: () => setState(() => current = original.copyWith(frameVisible: true, effectVisible: true)),
            child: const Text('Сбросить изменения'),
          ),
          hint('Правки сохраняются в проекте. Исходный файл не меняется.'),
        ]),
      );
}

class PhotosPage extends StatefulWidget {
  final Store store;
  const PhotosPage({super.key, required this.store});
  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  bool busy = false;
  Future<void> pick() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final r = await widget.store.addPhotos();
      if (!mounted) return;
      if (r.errors.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Не все файлы добавлены'),
            content: SingleChildScrollView(child: Text(r.errors.take(8).join('\n'))),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Понятно'))],
          ),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) message(context, e.message ?? 'Не удалось открыть галерею');
    } catch (_) {
      if (mounted) message(context, 'Не удалось добавить фотографии');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => StoreBuilder(
        animation: widget.store,
        builder: (c, _) {
          final s = widget.store;
          return PageShell(
            store: s,
            title: 'Фотографии',
            bottom: Primary(
              'Продолжить',
              onTap: s.photos.isEmpty || busy ? null : () => open(c, Editor(store: s)),
            ),
            child: scroll([
              h1('Добавьте фотографии'),
              space(8),
              hint('Выберите фотографии в галерее. До 20 МБ на файл.'),
              space(20),
              Box(
                color: blue,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    section('Выбрано: ${s.photos.length}'),
                    space(6),
                    hint('Фотографии сохраняются на этом устройстве.'),
                    space(15),
                    Primary(busy ? 'Открываем галерею…' : 'Выбрать из галереи', onTap: busy ? null : pick),
                  ],
                ),
              ),
              space(20),
              if (s.photos.isEmpty)
                hint('Пока нет добавленных файлов.')
              else ...[
                section('Добавленные файлы'),
                space(8),
                ...s.photos.asMap().entries.map((e) => photoRow(s, e.key)),
              ],
            ]),
          );
        },
      );
      
  Widget photoRow(Store s, int i) {
    final p = s.photos[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Box(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(width: 48, height: 48, child: Center(child: PhotoPreview(store: s, photo: p, decodeWidth: 200))),
          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: const Text('Нажмите, чтобы изменить'),
          onTap: () => open(context, PhotoEditor(store: s, photo: p)),
          trailing: IconButton(tooltip: 'Удалить', onPressed: () => s.removePhoto(i), icon: const Icon(Icons.close)),
        ),
      ),
    );
  }
}

class Editor extends StatefulWidget {
  final Store store;
  const Editor({super.key, required this.store});
  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  @override
  Widget build(BuildContext c) => StoreBuilder(
        animation: widget.store,
        builder: (c, _) {
          final s = widget.store;
          return PageShell(
            store: s,
            title: 'Редактор проекта',
            bottom: Primary(
              'Проверить проект',
              onTap: s.photos.isEmpty ? null : () => open(c, CheckPage(store: s)),
            ),
            child: scroll([
              h1('Мой проект'),
              space(7),
              hint('${s.product.title} · ${s.format}${s.isBook ? ' · ${s.pages}' : ''}'),
              space(18),
              Primary(
                'Открыть фоторедактор',
                outline: true,
                onTap: s.photos.isEmpty ? null : () => open(c, PhotoComposer(store: s)),
              ),
              space(8),
              hint('Перемещайте слой одним пальцем, двумя — масштабируйте и поворачивайте.'),
              if (s.composition?['preview'] is String && s.photoDirectory != null) ...[
                space(12),
                section('Композиция'),
                space(6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File('${s.photoDirectory}/${s.composition!['preview']}'),
                    height: 220, width: double.infinity, cacheHeight: 660, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => hint('Предпросмотр недоступен.'),
                  ),
                ),
                hint('Это предварительный рисунок, а не печатный файл.'),
              ],
              space(16),
              if (s.isBook) ...[
                BookSpreadsPanel(store: s),
                space(12),
              ],
              Row(
                children: [
                  Expanded(child: section('Фотографии')),
                  TextButton(onPressed: () => open(c, PhotosPage(store: s)), child: const Text('Добавить')),
                ],
              ),
              hint('Нажмите на фото, чтобы изменить его. Удерживайте строку, чтобы поменять порядок.'),
              space(8),
              if (s.photos.isEmpty)
                hint('Добавьте фотографии, чтобы продолжить.')
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: s.photos.length,
                  onReorder: s.movePhoto,
                  itemBuilder: (c, i) {
                    final p = s.photos[i];
                    return ListTile(
                      key: ValueKey(p.id),
                      contentPadding: EdgeInsets.zero,
                      leading: SizedBox(width: 48, height: 48, child: Center(child: PhotoPreview(store: s, photo: p, decodeWidth: 200))),
                      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${p.width} × ${p.height} px'),
                      onTap: () => open(c, PhotoEditor(store: s, photo: p)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(tooltip: 'Удалить', onPressed: () => s.removePhoto(i), icon: const Icon(Icons.close)),
                          const Icon(Icons.drag_handle),
                        ],
                      ),
                    );
                  },
                ),
            ]),
          );
        },
      );
}