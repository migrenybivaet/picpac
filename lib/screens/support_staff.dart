part of '../main.dart';

class SupportStaffLogin extends StatefulWidget {
  final Store store;
  const SupportStaffLogin({super.key, required this.store});
  @override
  State<SupportStaffLogin> createState() => _SupportStaffLoginState();
}

class _SupportStaffLoginState extends State<SupportStaffLogin> {
  final email = TextEditingController(text: 'support@picpac.local'),
      password = TextEditingController();
  bool busy = false, visible = false;
  String? error, accessState;
  @override
  void initState() {
    super.initState();
    refreshAccessState();
  }

  Future<void> refreshAccessState() async {
    try {
      final state = await widget.store.storage.staffAccessState('support');
      if (mounted) setState(() => accessState = state);
    } catch (_) {
      if (mounted) setState(() => accessState = 'error');
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final address = email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address) ||
        address.length > 254 ||
        password.text.length < 8 ||
        password.text.length > 128) {
      setState(() => error = 'Проверьте email и пароль.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final account = await widget.store.storage.authenticateSupport(
        address,
        password.text,
      );
      widget.store.setSupport(account);
      if (mounted)
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SupportStaffPanel(store: widget.store),
          ),
        );
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => error = switch (e.code) {
              'AUTH_FAILED' => address.toLowerCase() ==
                          'support@picpac.local' &&
                      accessState == 'missing'
                  ? 'Доступ ещё не создан. Сначала создайте доступ на этом телефоне.'
                  : 'Неверный логин или пароль. Если забыли пароль, восстановите доступ.',
              'DISABLED' =>
                'Прежний публичный пароль отключён. Настройте новый доступ.',
              _ =>
                'Ошибка входа или хранилища. Попробуйте снова; данные не изменены.',
            });
      }
    } catch (_) {
      if (mounted)
        setState(() => error = 'Ошибка входа или хранилища. Попробуйте снова.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => PageShell(
        store: widget.store,
        title: 'Вход поддержки',
        child: scroll([
          h1('Кабинет поддержки'),
          space(8),
          hint(staffStateHint(accessState)),
          space(20),
          TextField(
            controller: email,
            enabled: !busy,
            maxLength: 254,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email сотрудника'),
          ),
          space(12),
          TextField(
            controller: password,
            enabled: !busy,
            maxLength: 128,
            obscureText: !visible,
            decoration: InputDecoration(
              labelText: 'Пароль',
              suffixIcon: IconButton(
                onPressed: () => setState(() => visible = !visible),
                icon: Icon(
                  visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          if (error != null) ...[
            space(8),
            Text(error!, style: const TextStyle(color: red)),
          ],
          space(18),
          Primary('Войти', onTap: busy ? null : submit),
          space(8),
          Primary(
            'Создать или восстановить доступ',
            outline: true,
            onTap: busy
                ? null
                : () async {
                    final value = await open<String>(
                        c, StaffSetup(store: widget.store, role: 'support'));
                    if (!mounted) return;
                    if (value != null) {
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (_) => SupportStaffPanel(store: widget.store),
                      ));
                    } else {
                      await refreshAccessState();
                    }
                  },
          ),
        ]),
      );
}

class SupportStaffPanel extends StatelessWidget {
  final Store store;
  const SupportStaffPanel({super.key, required this.store});
  @override
  Widget build(BuildContext c) => StaffGate(
        store: store,
        adminOnly: false,
        child: StoreBuilder(
          animation: store,
          builder: (c, _) {
            final threads = <String, Map<String, dynamic>>{};
            for (final m in store.supportMessages) {
              if ((m['owner'] as String? ?? '').isNotEmpty)
                threads[jsonEncode([m['owner'], m['order'] ?? ''])] = m;
            }
            final awaiting =
                threads.values.where((m) => m['sender'] == 'Вы').length;
            return PageShell(
              store: store,
              title: 'Поддержка',
              child: scroll([
                h1('Рабочее место'),
                space(8),
                hint('${store.supportEmail ?? ''} · только это устройство'),
                space(20),
                Box(
                  color: mint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      section('Обращения клиентов'),
                      space(8),
                      Text('${threads.length} чатов · $awaiting ждут ответа'),
                    ],
                  ),
                ),
                space(16),
                Primary(
                  'Открыть чаты',
                  onTap: () => open(c, AdminSupport(store: store)),
                ),
                space(12),
                Primary(
                  'Выйти',
                  outline: true,
                  onTap: () async {
                    try {
                      await store.storage.supportLogout();
                      store.setSupport(null);
                      if (c.mounted) showMain(c, store, 3);
                    } catch (_) {
                      if (c.mounted) message(c, 'Не удалось выйти.');
                    }
                  },
                ),
              ]),
            );
          },
        ),
      );
}
