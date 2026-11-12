part of '../main.dart';

class QuickOrder extends StatefulWidget {
  final Store store;
  const QuickOrder({super.key, required this.store});
  @override
  State<QuickOrder> createState() => _QuickOrderState();
}

class _QuickOrderState extends State<QuickOrder> {
  bool busy = false;
  Future<void> pick() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await widget.store.addPhotos();
      if (mounted && result.errors.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Не все файлы добавлены'),
            content: SingleChildScrollView(
              child: Text(result.errors.take(8).join('\n')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Понятно'),
              ),
            ],
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

  Future<void> next() async {
    final s = widget.store;
    if (s.photos.isEmpty || busy) return;
    if (s.lowCount > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Проверьте качество'),
          content: Text(
            'Фото с низким разрешением: ${s.lowCount}. Они могут получиться нечёткими. Можно вернуться и заменить их или продолжить.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Вернуться'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Продолжить с этими фото'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    s.inCart = true;
    s.changed();
    if (await requireAccount(context, s) && mounted) {
      if (s.inCart && s.photos.isNotEmpty) {
        await open(context, Checkout(store: s));
      } else {
        message(
          context,
          'Проект не перенесён. Выберите фотографии в аккаунте.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext c) => StoreBuilder(
        animation: widget.store,
        builder: (c, _) {
          final s = widget.store;
          return PageShell(
            store: s,
            title: 'Быстрая печать',
            bottom: Primary(
              'К оформлению · ${money(s.subtotal)}',
              onTap: s.photos.isEmpty || busy ? null : next,
            ),
            child: scroll([
              h1('Напечатать фотографии'),
              space(6),
              hint(
                  'Выберите снимки и формат. Оформление займёт всего пару шагов.'),
              space(16),
              Box(
                color: mint,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.photo_library_outlined, color: ink),
                        const SizedBox(width: 10),
                        Expanded(
                          child: section('Выбрано фото: ${s.photos.length}'),
                        ),
                      ],
                    ),
                    space(12),
                    Primary(
                      busy ? 'Открываем галерею…' : 'Выбрать из галереи',
                      onTap: busy ? null : pick,
                    ),
                  ],
                ),
              ),
              if (s.photos.isNotEmpty) ...[
                space(14),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: s.photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (c, i) => SizedBox(
                      width: 88,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: PhotoPreview(
                                  store: s, photo: s.photos[i], decodeWidth: 600),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => s.removePhoto(i),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.close, size: 16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                space(8),
                TextButton.icon(
                  onPressed: () => open(c, Editor(store: s)),
                  icon: const Icon(Icons.tune),
                  label: const Text('Редактировать фото и порядок'),
                ),
              ],
              space(16),
              section('Формат'),
              space(6),
              Wrap(
                spacing: 7,
                children: List.generate(
                  s.formats.length,
                  (i) => ChoiceChip(
                    label: Text(s.formats[i]),
                    selected: s.formatIndex == i,
                    onSelected: (_) {
                      s.formatIndex = i;
                      s.changed();
                    },
                  ),
                ),
              ),
              space(12),
              Box(
                child: Row(
                  children: [
                    const Expanded(child: Text('Копий каждого фото')),
                    IconButton(
                      tooltip: 'Уменьшить количество',
                      onPressed: s.quantity > 1
                          ? () {
                              s.quantity--;
                              s.changed();
                            }
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '${s.quantity}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      tooltip: 'Увеличить количество',
                      onPressed: s.quantity < 99
                          ? () {
                              s.quantity++;
                              s.changed();
                            }
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
              space(12),
              totals('Фото', '${s.photos.length} × ${s.quantity}'),
              totals('Итого без доставки', money(s.subtotal), strong: true),
              space(5),
              hint('Стоимость условная. Оплата и заказ пока демонстрационные.'),
            ]),
          );
        },
      );
}
