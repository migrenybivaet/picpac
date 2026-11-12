part of '../main.dart';

class StaffGate extends StatelessWidget {
  final Store store;
  final bool adminOnly;
  final Widget child;
  const StaffGate({
    super.key,
    required this.store,
    required this.child,
    this.adminOnly = true,
  });

  Future<bool> _allowed() async {
    // Сначала проверяем наше внутреннее состояние (для хардкод-логинов)
    if (store.adminEmail != null) return true;
    if (!adminOnly && store.supportEmail != null) return true;
    
    // Затем проверяем нативное хранилище (для обычных входов)
    if (await store.storage.adminState() != null) return true;
    return !adminOnly && await store.storage.supportState() != null;
  }

  @override
  Widget build(BuildContext context) => StoreBuilder(
        animation: store,
        builder: (context, _) {
          if (store.adminEmail == null &&
              (adminOnly || store.supportEmail == null)) {
            return const Scaffold(
              body: Center(
                child: Text(
                  'Доступ только для сотрудников. Войдите в нужный аккаунт.',
                ),
              ),
            );
          }
          return FutureBuilder<bool>(
            future: _allowed(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              if (snapshot.hasError || snapshot.data != true)
                return const Scaffold(
                  body: Center(
                    child: Text('Доступ запрещён. Войдите в нужный аккаунт.'),
                  ),
                );
              return child;
            },
          );
        },
      );
}

class StaffSetup extends StatefulWidget {
  final Store store;
  final String role;
  const StaffSetup({super.key, required this.store, required this.role});
  @override
  State<StaffSetup> createState() => _StaffSetupState();
}

class _StaffSetupState extends State<StaffSetup> {
  final password = TextEditingController(), confirm = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> save() async {
    // ЗАПРЕТ НА СМЕНУ ПАРОЛЯ
    final exists = widget.role == 'admin' 
        ? await widget.store.storage.adminExists() 
        : (await widget.store.storage.staffAccessState('support') == 'ready');

    if (exists) {
      setState(() => error = 'Пароль уже установлен. Смена пароля администратором системы запрещена.');
      return;
    }

    if (password.text.length < 12 ||
        password.text.length > 128 ||
        ['PicPacAdmin2026!', 'PicPacSupport2026!'].contains(password.text)) {
      setState(() => error = 'Выберите новый пароль от 12 до 128 символов.');
      return;
    }
    if (password.text != confirm.text) {
      setState(() => error = 'Пароли не совпадают.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final login = await widget.store.storage.setupStaff(
        widget.role,
        password.text,
      );
      if (widget.role == 'admin' && widget.store.adminEmail == login) {
        widget.store.setAdmin(null);
      }
      if (widget.role == 'support' && widget.store.supportEmail == login) {
        widget.store.setSupport(null);
      }
      if (!mounted) return;
      
      String account;
      try {
        account = widget.role == 'admin'
            ? await widget.store.storage
                .authenticateAdmin(login, password.text, setup: false)
            : await widget.store.storage
                .authenticateSupport(login, password.text);
      } catch (_) {
        if (mounted) {
          setState(() => error =
              'Пароль сохранён, но автоматический вход не удался. Вернитесь назад и войдите с новым паролем.');
        }
        return;
      }
      if (!mounted) {
        if (widget.role == 'admin') {
          await widget.store.storage.adminLogout();
        } else {
          await widget.store.storage.supportLogout();
        }
        return;
      }
      if (widget.role == 'admin') {
        widget.store.setAdmin(account);
      } else {
        widget.store.setSupport(account);
      }
      Navigator.pop(context, account);
    } on PlatformException catch (e) {
      if (mounted)
        setState(
          () => error = switch (e.code) {
            'NO_DEVICE_LOCK' =>
              'Установите PIN, пароль или графический ключ блокировки телефона и повторите.',
            'CANCELLED' =>
              'Подтверждение владельца отменено. Пароль не изменён.',
            _ => e.message ?? 'Не удалось настроить доступ.',
          },
        );
    } catch (_) {
      if (mounted) setState(() => error = 'Не удалось настроить доступ.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final login =
        widget.role == 'admin' ? 'admin@picpac.local' : 'support@picpac.local';
    return PageShell(
      store: widget.store,
      title: 'Настройка сотрудника',
      child: scroll([
        h1('Настройка доступа'),
        space(8),
        hint(
          'Логин: $login. Придумайте личный пароль и подтвердите PIN, пароль или графический ключ телефона. После этого откроется кабинет.',
        ),
        space(16),
        TextField(
          controller: password,
          obscureText: true,
          maxLength: 128,
          enabled: !busy,
          decoration: const InputDecoration(labelText: 'Новый пароль'),
        ),
        space(10),
        TextField(
          controller: confirm,
          obscureText: true,
          maxLength: 128,
          enabled: !busy,
          decoration: const InputDecoration(labelText: 'Повторите пароль'),
        ),
        if (error != null) ...[
          space(8),
          Text(error!, style: const TextStyle(color: red)),
        ],
        space(14),
        Primary('Подтвердить на телефоне', onTap: busy ? null : save),
      ]),
    );
  }
}

String staffStateHint(String? state) => switch (state) {
      'missing' =>
        'Доступ ещё не настроен. Нажмите «Создать доступ».',
      'disabled' =>
        'Доступ отключён. Обратитесь к администратору.',
      'ready' =>
        'Войдите с личным паролем.',
      'error' =>
        'Не удалось проверить состояние доступа. Попробуйте снова.',
      _ =>
        'Первый вход: создайте доступ и подтвердите блокировку телефона.',
    };