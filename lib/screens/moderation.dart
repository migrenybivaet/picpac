part of '../main.dart';

class AdminModerationList extends StatelessWidget {
  final Store store;
  const AdminModerationList({super.key, required this.store});
  @override
  Widget build(BuildContext c) => StaffGate(
        store: store,
        adminOnly: true,
        child: StoreBuilder(
          animation: store,
          builder: (c, _) => PageShell(
            store: store,
            title: 'Модерация',
            child: scroll([
              h1('Модерация'),
              space(8),
              hint(
                'Проверяйте материалы каждого заказа перед передачей в производство.',
              ),
              space(16),
              if (store.orders.isEmpty)
                const Box(child: Text('Заказов пока нет.')),
              ...store.orders.map(
                (o) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Box(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.photo_library_outlined),
                      title: Text(
                        '${o['id']} · ${o['moderation'] ?? 'На проверке'}',
                      ),
                      subtitle: Text(
                        '${o['account'] ?? '—'} · ${o['count'] ?? 0} фото',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          open(c, ModerationDetail(store: store, order: o)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}

class ModerationDetail extends StatefulWidget {
  final Store store;
  final Map<String, dynamic> order;
  const ModerationDetail({super.key, required this.store, required this.order});
  @override
  State<ModerationDetail> createState() => _ModerationDetailState();
}

class _ModerationDetailState extends State<ModerationDetail> {
  final reason = TextEditingController();
  bool busy = false;
  @override
  void initState() {
    super.initState();
    reason.text = (widget.order['moderationComment'] ?? '').toString();
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> decide(String value) async {
    setState(() => busy = true);
    try {
      await widget.store.adminModerateOrder(widget.order, value, reason.text);
      if (mounted) message(context, 'Решение сохранено');
    } catch (e) {
      if (mounted)
        message(
          context,
          e is StateError
              ? e.message.toString()
              : 'Не удалось сохранить решение.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => StaffGate(
        store: widget.store,
        adminOnly: true,
        child: StoreBuilder(
          animation: widget.store,
          builder: (c, _) {
            final s = widget.store, o = widget.order;
            final photos = (o['photoData'] as List? ?? [])
                .whereType<Map>()
                .map((p) {
                  try {
                    return Photo.fromMap(Map<String, dynamic>.from(p));
                  } catch (_) {
                    return null;
                  }
                })
                .whereType<Photo>()
                .toList();
            final available = s.orderPhotosAvailable(o);
            return PageShell(
              store: s,
              title: 'Проверка заказа',
              child: scroll([
                h1('Заказ ${o['id']}'),
                space(8),
                hint('Покупатель: ${o['account'] ?? '—'}'),
                hint('Решение: ${o['moderation'] ?? 'На проверке'}'),
                space(16),
                if (!available)
                  const Box(
                    color: blue,
                    child: Text(
                      'Материалы недоступны. Старые заказы не содержат снимка фотографий; одобрить их нельзя.',
                    ),
                  ),
                if (photos.isNotEmpty) ...[
                  section('Фотографии'),
                  space(8),
                  ...photos.map(
                    (photo) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Box(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: SizedBox(
                            width: 54,
                            height: 54,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: PhotoPreview(
                                  store: s, photo: photo, decodeWidth: 220),
                            ),
                          ),
                          title: Text(
                            photo.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${photo.width} × ${photo.height}${photo.lowResolution ? ' · низкое разрешение' : ''}',
                          ),
                          trailing: const Icon(Icons.zoom_in),
                          onTap: () => showDialog<void>(
                            context: c,
                            builder: (d) => Dialog(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      onPressed: () => Navigator.pop(d),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 360,
                                    child: InteractiveViewer(
                                      child:
                                          PhotoPreview(store: s, photo: photo),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (s.photoDirectory != null &&
                    o['compositionPreview'] is String &&
                    RegExp(r'^composition-\d+\.png$')
                        .hasMatch(o['compositionPreview'] as String)) ...[
                  space(12),
                  section('Предпросмотр'),
                  space(8),
                  Image.file(
                    File('${s.photoDirectory}/${o['compositionPreview']}'),
                    height: 220,
                    cacheHeight: 660,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        hint('Предпросмотр недоступен.'),
                  ),
                  hint('Предпросмотр, не файл для печати.'),
                ],
                space(16),
                TextField(
                  controller: reason,
                  maxLength: 300,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий или причина отказа',
                  ),
                ),
                space(8),
                Primary(
                  'Одобрить',
                  onTap: busy || !available ? null : () => decide('Одобрено'),
                ),
                space(8),
                Primary(
                  'Отклонить',
                  outline: true,
                  onTap: busy ? null : () => decide('Отклонено'),
                ),
              ]),
            );
          },
        ),
      );
}
