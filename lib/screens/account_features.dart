part of '../main.dart';

class NotificationsPage extends StatefulWidget {
  final Store store;
  const NotificationsPage({super.key, required this.store});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    // Автоматически отмечаем все уведомления прочитанными при входе на экран
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bool changed = false;
      for (final n in widget.store.visibleNotifications) {
        if (n['read'] != true) {
          n['read'] = true;
          changed = true;
        }
      }
      if (changed) widget.store.changed();
    });
  }

  @override
  Widget build(BuildContext c) => StoreBuilder(
        animation: widget.store,
        builder: (c, _) => PageShell(
          store: widget.store,
          title: 'Уведомления',
          child: scroll([
            h1('Уведомления'),
            space(8),
            hint('Тестовые события сохраняются на этом устройстве.'),
            space(12),
            if (widget.store.visibleNotifications.isEmpty)
              const Box(child: Text('Пока нет уведомлений.')),
            ...widget.store.visibleNotifications.map(
              (n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Box(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      n['read'] == true
                          ? Icons.notifications_none
                          : Icons.notifications_active_outlined,
                      color: ink,
                    ),
                    title: Text(n['title'].toString()),
                    subtitle: Text(n['body'].toString()),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                widget.store.notifyLocal(
                    'Скидка 10%', 'Тестовая акция: промокод PIC10.');
                widget.store.changed();
              },
              child: const Text('Показать тестовую скидку'),
            ),
          ]),
        ),
      );
}

// ... (Остальной код файла EditProfile и DemoCardPage остается без изменений)
class EditProfile extends StatefulWidget {
  final Store store;
  const EditProfile({super.key, required this.store});
  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name,
      address,
      phone,
      vk,
      telegram,
      instagram;
  @override
  void initState() {
    super.initState();
    final s = widget.store;
    name = TextEditingController(text: s.profileName);
    address = TextEditingController(text: s.profileAddress);
    phone = TextEditingController(text: s.profilePhone);
    vk = TextEditingController(text: s.socialProfiles['vk']);
    telegram = TextEditingController(text: s.socialProfiles['telegram']);
    instagram = TextEditingController(text: s.socialProfiles['instagram']);
  }

  @override
  void dispose() {
    for (final c in [name, address, phone, vk, telegram, instagram]) {
      c.dispose();
    }
    super.dispose();
  }

  String? urlError(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final u = Uri.tryParse(v);
    if (v.length > 200 ||
        u == null ||
        u.scheme != 'https' ||
        u.host.isEmpty ||
        u.userInfo.isNotEmpty) return 'Введите ссылку вида https://...';
    return null;
  }

  void save() {
    if (!form.currentState!.validate()) return;
    final s = widget.store;
    s.profileName = name.text.trim();
    s.profileAddress = address.text.trim();
    s.profilePhone = phone.text.trim();
    s.socialProfiles = {
      'vk': vk.text.trim(),
      'telegram': telegram.text.trim(),
      'instagram': instagram.text.trim(),
    };
    s.changed();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext c) => PageShell(
        store: widget.store,
        title: 'Личные данные',
        bottom: Primary('Сохранить', onTap: save),
        child: Form(
          key: form,
          child: scroll([
            h1('Личные данные'),
            space(8),
            hint('Данные сохраняются только на этом устройстве.'),
            space(16),
            TextFormField(
              controller: name,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'ФИО'),
              validator: (v) => fullNameError(v ?? ''),
            ),
            space(8),
            TextFormField(
              controller: phone,
              maxLength: 24,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Телефон'),
              validator: (v) => phoneError(v ?? ''),
            ),
            space(8),
            TextFormField(
              controller: address,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Адрес доставки'),
              validator: (v) => addressError(v ?? ''),
            ),
            space(16),
            section('Ссылки на соцсети'),
            space(5),
            hint('Это ссылки в профиле, не вход через соцсети.'),
            space(8),
            TextFormField(
              controller: vk,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'ВКонтакте (https://...)',
              ),
              validator: urlError,
            ),
            space(10),
            TextFormField(
              controller: telegram,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Telegram (https://...)',
              ),
              validator: urlError,
            ),
            space(10),
            TextFormField(
              controller: instagram,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Instagram (https://...)',
              ),
              validator: urlError,
            ),
          ]),
        ),
      );
}

class DemoCardPage extends StatefulWidget {
  final Store store;
  const DemoCardPage({super.key, required this.store});
  @override
  State<DemoCardPage> createState() => _DemoCardPageState();
}

class _DemoCardPageState extends State<DemoCardPage> {
  final last4 = TextEditingController();
  @override
  void dispose() {
    last4.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => PageShell(
        store: widget.store,
        title: 'Тестовая карта',
        child: scroll([
          h1('Тестовая карта'),
          space(8),
          hint(
            'Это только имитация: оплаты и привязки банковской карты нет. Не вводите данные настоящей карты.',
          ),
          space(16),
          TextField(
            controller: last4,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: const InputDecoration(
              labelText: 'Последние 4 цифры тестовой карты',
              hintText: '4242',
            ),
          ),
          space(12),
          Primary(
            'Добавить тестовую карту',
            onTap: () {
              if (!RegExp(r'^\d{4}$').hasMatch(last4.text)) {
                message(c, 'Введите 4 цифры тестовой карты.');
                return;
              }
              widget.store.cardLast4 = last4.text;
              widget.store.changed();
              Navigator.pop(c);
            },
          ),
          if (widget.store.cardLast4.isNotEmpty)
            TextButton(
              onPressed: () {
                widget.store.cardLast4 = '';
                widget.store.changed();
                Navigator.pop(c);
              },
              child: const Text('Удалить тестовую карту'),
            ),
        ]),
      );
}