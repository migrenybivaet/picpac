part of '../main.dart';

class AdminLogin extends StatefulWidget {
  final Store store;
  const AdminLogin({super.key, required this.store});
  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  @override
  Widget build(BuildContext c) => AuthPage(store: widget.store);
}

class AdminPanel extends StatefulWidget {
  final Store store;
  const AdminPanel({super.key, required this.store});
  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  @override
  Widget build(BuildContext c) => StaffGate(
        store: widget.store,
        adminOnly: true,
        child: StoreBuilder(
          animation: widget.store,
          builder: (c, _) {
            final s = widget.store;
            final allOrders = s.orders;
            final pendingOrders = allOrders.where((o) => o['status'] == 'Принят').toList();
            final total = allOrders.fold<int>(0, (n, o) => n + ((o['total'] as num?)?.toInt() ?? 0));

            return Scaffold(
              appBar: AppBar(
                title: const Text('Админ-панель'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout, color: red),
                    onPressed: () async {
                      try {
                        await s.storage.adminLogout();
                        s.setAdmin(null);
                        if (c.mounted) showMain(c, s, 3);
                      } catch (_) {}
                    },
                  )
                ],
              ),
              body: Container(
                decoration: const BoxDecoration(gradient: softGradient),
                child: scroll([
                  h1('Панель управления'),
                  space(10),
                  hint('Вы вошли как ${s.adminEmail ?? ''}'),
                  space(20),
                  
                  Row(
                    children: [
                      _statCard('Оборот', money(total), peach),
                      const SizedBox(width: 12),
                      _statCard('Заказы', '${allOrders.length}', mint),
                    ],
                  ),
                  space(24),

                  if (pendingOrders.isNotEmpty) ...[
                    section('Ожидают подтверждения (${pendingOrders.length})'),
                    space(10),
                    ...pendingOrders.map((o) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _pendingOrderCard(c, o),
                    )),
                    space(24),
                  ],

                  section('Управление'),
                  space(10),
                  Box(
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: const Text('Все заказы'),
                          subtitle: Text('${allOrders.length} на сервере'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => open(c, AdminOrders(store: s)),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.fact_check_outlined),
                          title: const Text('Модерация'),
                          subtitle: Text('${s.orders.where((o) => (o['moderation'] ?? 'На проверке') == 'На проверке').length} ожидают проверки'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => open(c, AdminModerationList(store: s)),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.support_agent),
                          title: const Text('Обращения'),
                          subtitle: Text('${s.supportMessages.length} сообщений'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => open(c, AdminSupport(store: s)),
                        ),
                      ],
                    ),
                  ),
                  space(20),
                ]),
              ),
            );
          },
        ),
      );

  Widget _statCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, color: ink, fontWeight: FontWeight.w600)),
            space(6),
            Text(value, style: const TextStyle(fontSize: 22, color: ink, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _pendingOrderCard(BuildContext c, Map<String, dynamic> o) {
    return Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.new_releases, color: red),
              const SizedBox(width: 8),
              Text(o['id'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(money((o['total'] as num?)?.toInt() ?? 0), style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          space(6),
          Text('${o['customer_name'] ?? 'Гость'} · ${o['product']}'),
          space(12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: red),
                  onPressed: () async {
                    try {
                      await widget.store.adminSetOrderStatus(o, 'Производство');
                      if (c.mounted) message(c, 'Заказ подтверждён!');
                    } catch (e) {
                      if (c.mounted) message(c, e is StateError ? e.message : 'Ошибка сети');
                    }
                  },
                  child: const Text('Подтвердить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminOrders extends StatelessWidget {
  final Store store;
  const AdminOrders({super.key, required this.store});
  @override
  Widget build(BuildContext c) => StaffGate(
        store: store,
        adminOnly: true,
        child: StoreBuilder(
          animation: store,
          builder: (c, _) => PageShell(
            store: store,
            title: 'Управление заказами',
            child: scroll([
              h1('Заказы'),
              space(7),
              hint('Все заказы из облака.'),
              space(14),
              if (store.orders.isEmpty) const Box(child: Text('Заказов пока нет.')),
              ...store.orders.map(
                (o) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Box(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${o['id']} · ${o['status']}'),
                      subtitle: Text('${o['customer_name'] ?? ''}\n${money((o['total'] as num?)?.toInt() ?? 0)}'),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => open(c, AdminOrderDetail(store: store, order: o)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}

class AdminOrderDetail extends StatefulWidget {
  final Store store;
  final Map<String, dynamic> order;
  const AdminOrderDetail({super.key, required this.store, required this.order});
  @override
  State<AdminOrderDetail> createState() => _AdminOrderDetailState();
}

class _AdminOrderDetailState extends State<AdminOrderDetail> {
  bool busy = false;

  @override
  Widget build(BuildContext c) {
    final o = widget.order;
    return StaffGate(
      store: widget.store,
      adminOnly: true,
      child: PageShell(
        store: widget.store,
        title: 'Заказ ${o['id']}',
        child: scroll([
          h1('Заказ ${o['id']}'),
          space(8),
          hint('Покупатель: ${o['customer_name'] ?? 'Гость'}'),
          space(16),
          Box(
            child: Column(
              children: [
                totals('Продукт', o['product'].toString()),
                totals('Сумма', money((o['total'] as num?)?.toInt() ?? 0), strong: true),
                totals('Телефон', '${o['phone'] ?? '—'}'),
                totals('Адрес', '${o['address'] ?? '—'}'),
              ],
            ),
          ),
          space(20),
          section('Статус заказа'),
          space(8),
          ...Store.orderStages.map(
            (status) => RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: Text(status),
              value: status,
              groupValue: o['status'] as String?,
              onChanged: busy
                  ? null
                  : (value) async {
                      if (value == null) return;
                      setState(() => busy = true);
                      try {
                        await widget.store.adminSetOrderStatus(o, value);
                        if (c.mounted) {
                          message(c, 'Статус сохранён');
                          Navigator.pop(c);
                        }
                      } catch (e) {
                        if (c.mounted) message(c, e is StateError ? e.message : 'Не удалось изменить статус');
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
            ),
          ),
        ]),
      ),
    );
  }
}

// ============================================================
//                      ОБРАЩЕНИЯ В ПОДДЕРЖКУ
// ============================================================

class AdminSupport extends StatelessWidget {
  final Store store;
  const AdminSupport({super.key, required this.store});
  @override
  Widget build(BuildContext c) => StaffGate(
        store: store,
        adminOnly: false,
        child: StoreBuilder(
          animation: store,
          builder: (c, _) {
            // Группируем по user_email и order_id
            final threads = <String, Map<String, dynamic>>{};
            for (final m in store.supportMessages) {
              if ((m['user_email'] as String? ?? '').isEmpty) continue;
              threads[jsonEncode([m['user_email'], m['order_id'] ?? ''])] = m;
            }
            final messages = threads.values.toList().reversed;
            
            return PageShell(
              store: store,
              title: 'Обращения',
              child: scroll([
                h1('Обращения'),
                space(7),
                hint('Синхронизированные сообщения.'),
                space(14),
                if (messages.isEmpty) const Box(child: Text('Обращений пока нет.')),
                ...messages.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Box(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${m['user_email']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          if ((m['order_id'] ?? '').toString().isNotEmpty) hint('Заказ ${m['order_id']}'),
                          space(6),
                          Text('${m['text_content']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                          hint(m['sender'] == 'Вы' ? 'Ожидает ответа' : 'Ответ отправлен'),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => open(
                                c,
                                AdminReply(
                                  store: store,
                                  owner: m['user_email'].toString(),
                                  order: (m['order_id'] ?? '').toString(),
                                ),
                              ),
                              child: const Text('Ответить'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            );
          },
        ),
      );
}

class AdminReply extends StatefulWidget {
  final Store store;
  final String owner, order;
  const AdminReply({super.key, required this.store, required this.owner, required this.order});
  @override
  State<AdminReply> createState() => _AdminReplyState();
}

class _AdminReplyState extends State<AdminReply> {
  final text = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final value = text.text.trim();
    if (value.length < 3 || value.length > 1000) {
      message(context, 'Введите сообщение от 3 до 1000 символов.');
      return;
    }
    setState(() => busy = true);
    try {
      await widget.store.sendAdminReply(widget.owner, value, orderId: widget.order);
      if (mounted) text.clear();
    } catch (e) {
      if (mounted) message(context, 'Не удалось сохранить ответ: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => StaffGate(
        store: widget.store,
        adminOnly: false,
        child: StoreBuilder(
            animation: widget.store,
            builder: (c, _) {
              // МАППИНГ ДАННЫХ
              final rawEntries = widget.store.supportMessages
                  .where((m) => m['user_email'] == widget.owner && (m['order_id'] ?? '') == widget.order)
                  .toList();
                  
              final entries = rawEntries.map((m) => {
                'text': m['text_content'] ?? '',
                'sender': m['sender'] ?? 'Вы',
                'time': m['created_at'] ?? DateTime.now().toIso8601String(),
              }).toList();

              return Scaffold(
                appBar: AppBar(
                    title: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(widget.owner, style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis),
                  Text(widget.order.isEmpty ? 'Обращение клиента' : 'Заказ ${widget.order}',
                      style: const TextStyle(fontSize: 11, color: secondary, fontWeight: FontWeight.normal)),
                ])),
                body: Container(
                    color: const Color(0xffe9f0ec),
                    child: Column(children: [
                      Expanded(child: ChatTranscript(entries: entries, staff: true)),
                      ChatComposer(controller: text, label: 'Ответ', button: 'Отправить ответ', busy: busy, send: send),
                    ])),
              );
            }),
      );
}