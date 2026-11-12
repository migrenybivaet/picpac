part of '../main.dart';

// ============================================================
// СОВРЕМЕННАЯ АНИМАЦИЯ ВХОДА (2 секунды)
// ============================================================

class WelcomeBookPage extends StatefulWidget {
  final Store store;
  const WelcomeBookPage({super.key, required this.store});
  @override
  State<WelcomeBookPage> createState() => _WelcomeBookPageState();
}

class _WelcomeBookPageState extends State<WelcomeBookPage> with TickerProviderStateMixin {
  late AnimationController _controller;
  
  late Animation<double> _iconScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    
    // Ровно 2 секунды
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

    // 1. Иконка выпрыгивает (0.0 - 0.5)
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)),
    );

    // 2. Текст появляется (0.3 - 0.7)
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 20), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic)),
    );

    // 3. Экран плавно уходит (0.8 - 1.0)
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.8, 1.0, curve: Curves.easeIn)),
    );

    _controller.forward().then((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => MainTabs(store: widget.store, initial: 0),
            transitionDuration: Duration.zero, // Сам переход уже сделан через Fade
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeOut,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [peach, pink, blue], // Фирменный пастельный градиент
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Логотип (Иконка фотоаппарата)
                ScaleTransition(
                  scale: _iconScale,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: red.withOpacity(0.2),
                          blurRadius: 40,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.photo_camera_rounded, size: 64, color: red),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Название
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: const Column(
                      children: [
                        Text(
                          'PicPac',
                          style: TextStyle(
                            fontSize: 48, 
                            fontWeight: FontWeight.w900, 
                            color: ink, 
                            letterSpacing: -1.5,
                          ),
                        ),
                        SizedBox(height: 8), // ИСПРАВЛЕНО
                        Text(
                          'Фотокниги и печать',
                          style: TextStyle(
                            fontSize: 16, 
                            color: secondary, 
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ЕДИНЫЙ ВХОД (Пользователь, Админ, Поддержка)
// ============================================================

class AuthPage extends StatefulWidget {
  final Store store;
  final bool returnToPrevious;
  const AuthPage({
    super.key,
    required this.store,
    this.returnToPrevious = false,
  });
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final fullName = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController();
  bool register = false, busy = false, visible = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    fullName.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final value = email.text.trim().toLowerCase();
    
    if (value.length > 254 || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      setState(() => error = 'Введите корректный email.');
      return;
    }
    if (password.text.length < 5) {
      setState(() => error = 'Пароль слишком короткий.');
      return;
    }

    setState(() { busy = true; error = null; });

    try {
      // Вход для Админа
      if (value == 'admin@picpac.local' && password.text == 'admin12345') {
        widget.store.setAdmin(value);
        if (mounted) {
          if (widget.returnToPrevious) Navigator.pop(context, true);
          else Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => AdminPanel(store: widget.store)), (_) => false);
        }
        return;
      }

      // Вход для Поддержки
      if (value == 'support@picpac.local' && password.text == 'support12345') {
        widget.store.setSupport(value);
        if (mounted) {
          if (widget.returnToPrevious) Navigator.pop(context, true);
          else Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => SupportStaffPanel(store: widget.store)), (_) => false);
        }
        return;
      }

      // Вход для обычного пользователя
      if (register) {
        final problem = fullNameError(fullName.text) ?? phoneError(phone.text) ?? addressError(address.text);
        if (problem != null) { setState(() { error = problem; busy = false; }); return; }
      }

      final result = await widget.store.storage.authenticate(value, password.text, register: register);
      widget.store.setAccount(result);
      if (register) {
        widget.store.profileName = fullName.text.trim();
        widget.store.profilePhone = phone.text.trim();
        widget.store.profileAddress = address.text.trim();
        widget.store.changed();
        await widget.store.flush();
        if (widget.store.saveFailed) {
          if (mounted) setState(() { register = false; error = 'Аккаунт создан, но профиль не сохранился.'; });
          return;
        }
      }
      if (mounted) {
        if (widget.returnToPrevious) Navigator.pop(context, true);
        else showMain(context, widget.store, 0);
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => error = e.code == 'AUTH_FAILED' ? 'Неверный логин или пароль.' : 'Ошибка доступа.');
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Не удалось выполнить вход.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => PageShell(
        store: widget.store,
        title: register ? 'Регистрация' : 'Вход',
        child: scroll([
          h1(register ? 'Создать аккаунт' : 'Войти в аккаунт'),
          space(20),
          TextField(
            controller: email,
            maxLength: 254,
            keyboardType: TextInputType.emailAddress,
            enabled: !busy,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          space(12),
          TextField(
            controller: password,
            maxLength: 128,
            obscureText: !visible,
            enabled: !busy,
            decoration: InputDecoration(
              labelText: 'Пароль',
              suffixIcon: IconButton(
                onPressed: () => setState(() => visible = !visible),
                icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              ),
            ),
          ),
          if (register) ...[
            space(12),
            TextField(
              controller: fullName,
              maxLength: 80,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'ФИО', hintText: 'Иванов Иван Иванович'),
            ),
            space(12),
            TextField(
              controller: phone,
              maxLength: 24,
              enabled: !busy,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Телефон', hintText: '+375 (29) 123-45-67'),
            ),
            space(12),
            TextField(
              controller: address,
              maxLength: 200,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Адрес доставки', hintText: 'г. Минск, ул. Ленина, д. 1'),
            ),
          ],
          if (error != null) ...[
            space(10),
            Text(error!, style: const TextStyle(color: red)),
          ],
          space(18),
          Primary(
            busy ? 'Подождите…' : (register ? 'Зарегистрироваться' : 'Войти'),
            onTap: busy ? null : submit,
          ),
          space(6),
          TextButton(
            onPressed: busy ? null : () => setState(() { register = !register; error = null; password.clear(); }),
            child: Text(register ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Зарегистрироваться'),
          ),
          space(14),
          const Divider(),
          space(10),
          Primary(
            'Продолжить как гость',
            outline: true,
            onTap: busy ? null : () async {
              try {
                if (widget.store.accountEmail != null) await widget.store.storage.logout();
                widget.store.setAccount(null);
                if (c.mounted) showMain(c, widget.store, 0);
              } catch (_) {
                if (c.mounted) message(c, 'Не удалось открыть гостевой режим.');
              }
            },
          ),
        ]),
      );
}