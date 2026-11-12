part of '../main.dart';

class Projects extends StatelessWidget {
  final Store store;
  const Projects({super.key, required this.store});

  @override
  Widget build(BuildContext c) => StoreBuilder(
        animation: store,
        builder: (c, _) => scroll([
          space(4),
          h1('Мои проекты'),
          space(7),
          hint('Черновики сохраняются на этом устройстве.'),
          if (store.unassignedLegacyDraft != null) ...[
            space(12),
            Box(
                color: peach,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      section('Старые проекты'),
                      space(6),
                      hint('Обнаружены проекты из предыдущей версии приложения.'),
                      if (store.accountEmail != null)
                        TextButton(
                            onPressed: () => _claimLegacy(c),
                            child: const Text('Восстановить проекты')),
                    ])),
          ],
          space(18),
          Primary(
            'Новый проект',
            onTap: () {
              store.startNewProject();
              showMain(c, store, 0);
            },
          ),
          space(18),
          if (store.needsReview) ...[
            const Box(
              color: pink,
              child: Text('Каталог обновлён. Проверьте параметры проекта.'),
            ),
            space(10),
          ],
          if (store.photos.isEmpty && store.savedProjects.isEmpty)
            const Box(
                color: peach, child: Text('Пока нет сохранённых проектов.')),
          if (store.photos.isNotEmpty) ...[
            section('Текущий проект'),
            space(8),
            Box(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  section(store.product.title),
                  space(6),
                  hint('${store.format} · ${store.photos.length} фото'),
                  space(12),
                  Primary(
                    'Продолжить',
                    outline: true,
                    onTap: () => open(c, Editor(store: store)),
                  ),
                ],
              ),
            ),
            space(16),
          ],
          if (store.savedProjects.isNotEmpty) ...[
            section('Сохранённые проекты'),
            space(8),
          ],
          ...store.savedProjects.map((p) {
            final product = products.where((e) => e.id == p['productKey']).toList();
            final title = product.isEmpty ? 'Проект' : product.first.title;
            final count = (p['photos'] as List? ?? []).length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Box(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: peach,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.collections_bookmark_outlined, color: ink),
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('$count фото'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    store.restoreProject(p['id'].toString());
                    open(c, Editor(store: store));
                  },
                ),
              ),
            );
          }),
        ]),
      );

  Future<void> _claimLegacy(BuildContext c) async {
    final ok = await showDialog<bool>(
        context: c,
        builder: (d) => AlertDialog(
              title: const Text('Восстановить старые проекты?'),
              content: const Text('Проекты и фото из прошлой версии приложения будут добавлены в текущий аккаунт.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Отмена')),
                TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Восстановить'))
              ],
            ));
    if (ok != true) return;
    try {
      await store.claimLegacyDrafts();
      if (c.mounted) message(c, 'Проекты восстановлены');
    } catch (_) {
      if (c.mounted) message(c, 'Не удалось восстановить.');
    }
  }
}

// ============================================================
//                      ПРОФИЛЬ
// ============================================================

class Profile extends StatelessWidget {
  final Store store;
  const Profile({super.key, required this.store});

  int get _fillPercent {
    var filled = 0;
    if (store.profileName.isNotEmpty) filled++;
    if (store.profilePhone.isNotEmpty) filled++;
    if (store.profileAddress.isNotEmpty) filled++;
    if (store.socialProfiles.values.any((v) => v.isNotEmpty)) filled++;
    if (store.cardLast4.isNotEmpty) filled++;
    return (filled / 5 * 100).round();
  }

  @override
  Widget build(BuildContext c) => StoreBuilder(
        animation: store,
        builder: (c, _) => SizedBox.expand(
          child: scroll([
            space(4),
            h1('Профиль'),
            space(14),
            _HeroCard(store: store),
            space(16),
            _QuickActions(store: store),
            space(20),
            
            if (store.myOrders.isNotEmpty) ...[
              section('Активный заказ'),
              space(8),
              _ActiveOrderCard(store: store, order: store.myOrders.first),
              space(20),
            ],
            
            if (store.accountEmail != null && _fillPercent < 100) ...[
              GestureDetector(
                onTap: () => open(c, ProfileChecklistPage(store: store)),
                child: _ProfileProgressCard(percent: _fillPercent),
              ),
              space(20),
            ],
            section('Аккаунт'),
            space(8),
            _AccountSection(store: store),
            space(20),
            section('Данные'),
            space(8),
            _DataSection(store: store),
            space(20),
          ]),
        ),
      );
}

// ============================================================
//                ЭКРАН ЭТАПОВ ЗАКАЗА
// ============================================================

class OrderTimelinePage extends StatelessWidget {
  final Store store;
  final Map<String, dynamic> order;
  const OrderTimelinePage({super.key, required this.store, required this.order});

  @override
  Widget build(BuildContext c) {
    final status = order['status'] as String? ?? 'Принят';
    final currentIdx = Store.orderStages.indexOf(status);
    
    final details = [
      'Заказ оформлен и оплачен. Ожидает проверки.',
      'Проверяем качество загруженных фотографий и макета.',
      'Ваш заказ передан в печать. Идет процесс изготовления.',
      'Заказ готов и упакован. Ожидает отправки.',
      'Курьер уже в пути или заказ готов к самовывозу.',
      'Заказ успешно получен. Спасибо, что выбрали нас!',
    ];

    return PageShell(
      store: store,
      title: 'Детали заказа',
      child: scroll([
        h1('Статус заказа'),
        space(8),
        hint('Номер: ${order['id']}'),
        hint('Товар: ${order['product']}'),
        space(20),
        for (var i = 0; i < Store.orderStages.length; i++) ...[
          _TimelineStep(
            index: i,
            title: Store.orderStages[i],
            description: details[i],
            isDone: i < currentIdx,
            isCurrent: i == currentIdx,
            isLast: i == Store.orderStages.length - 1,
          ),
        ],
      ]),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final int index;
  final String title, description;
  final bool isDone, isCurrent, isLast;

  const _TimelineStep({
    required this.index,
    required this.title,
    required this.description,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone ? mint : (isCurrent ? red : border);
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDone ? mint : (isCurrent ? red : Colors.white),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                    boxShadow: isCurrent ? [BoxShadow(color: red.withOpacity(0.3), blurRadius: 8)] : null,
                  ),
                  child: Center(
                    child: isDone 
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : isCurrent 
                        ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: isDone ? mint : border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 16,
                      color: isDone || isCurrent ? ink : secondary,
                    ),
                  ),
                  space(4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: isCurrent ? ink : secondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//                      HERO-КАРТОЧКА
// ============================================================

class _HeroCard extends StatelessWidget {
  final Store store;
  const _HeroCard({required this.store});

  @override
  Widget build(BuildContext c) {
    final isGuest = store.accountEmail == null;
    final name = isGuest
        ? 'Гостевой режим'
        : (store.profileName.isEmpty ? 'Мой профиль' : store.profileName);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: pinkGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x18dd5757), blurRadius: 26, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64, height: 64,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, red]),
                ),
                child: Container(
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: const Icon(Icons.person_outline, color: red, size: 30),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(isGuest: isGuest),
                      ],
                    ),
                    space(3),
                    hint(store.accountEmail ?? 'Войдите, чтобы оформлять заказы быстрее'),
                  ],
                ),
              ),
            ],
          ),
          space(18),
          Row(
            children: [
              _StatChip(value: '${store.myOrders.length}', label: 'заказов'),
              const SizedBox(width: 8),
              _StatChip(value: '${store.savedProjects.length}', label: 'проектов'),
              const SizedBox(width: 8),
              _StatChip(value: '${store.photos.length}', label: 'фото'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isGuest;
  const _StatusBadge({required this.isGuest});

  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isGuest ? Colors.white.withValues(alpha: .8) : mint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .7)),
        ),
        child: Text(
          isGuest ? 'гость' : 'активен',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ink, letterSpacing: .5),
        ),
      );
}

class _StatChip extends StatelessWidget {
  final String value, label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext c) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .75), borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11, color: secondary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

class _QuickActions extends StatelessWidget {
  final Store store;
  const _QuickActions({required this.store});

  @override
  Widget build(BuildContext c) => _ActionTile(
        icon: Icons.support_agent,
        label: 'Помощь и поддержка',
        onTap: () async {
          final navigator = Navigator.of(c);
          if (await requireAccount(c, store) && navigator.mounted) {
            await navigator.push(MaterialPageRoute(builder: (_) => Support(store: store)));
          }
        },
      );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext c) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border.withValues(alpha: .6)),
              boxShadow: const [BoxShadow(color: Color(0x0c263a35), blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: peach, shape: BoxShape.circle),
                    child: Icon(icon, color: ink, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ActiveOrderCard extends StatelessWidget {
  final Store store;
  final Map<String, dynamic> order;
  const _ActiveOrderCard({required this.store, required this.order});

  @override
  Widget build(BuildContext c) {
    final status = order['status'] as String? ?? 'Принят';
    final index = Store.orderStages.indexOf(status);
    final progress = index < 0 ? .1 : ((index + 1) / Store.orderStages.length).clamp(.1, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => open(c, OrderTimelinePage(store: store, order: order)),
        child: Box(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.local_shipping_outlined, color: ink, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order['product'].toString(), style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
                        space(3),
                        hint('${order['id']}'),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: peach, borderRadius: BorderRadius.circular(20)),
                    child: Text(status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink)),
                  ),
                ],
              ),
              space(14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: peach,
                  valueColor: const AlwaysStoppedAnimation(red),
                ),
              ),
              space(8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  hint('Этап ${index + 1} из ${Store.orderStages.length}'),
                  const Text('Подробнее >', style: TextStyle(fontSize: 12, color: red, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileChecklistPage extends StatelessWidget {
  final Store store;
  const ProfileChecklistPage({super.key, required this.store});

  @override
  Widget build(BuildContext c) => StoreBuilder(
        animation: store,
        builder: (c, _) {
          final hasName = store.profileName.isNotEmpty;
          final hasPhone = store.profilePhone.isNotEmpty;
          final hasAddress = store.profileAddress.isNotEmpty;
          final hasSocials = store.socialProfiles.values.any((v) => v.isNotEmpty);
          final hasCard = store.cardLast4.isNotEmpty;

          return PageShell(
            store: store,
            title: 'Заполнение профиля',
            child: scroll([
              h1('Что нужно заполнить'),
              space(8),
              hint('Заполните все пункты, чтобы ускорить оформление заказов.'),
              space(20),
              _checkItem(c, 'Личные данные', hasName && hasPhone, () => open(c, EditProfile(store: store))),
              _checkItem(c, 'Адрес доставки', hasAddress, () => open(c, EditProfile(store: store))),
              _checkItem(c, 'Социальные сети', hasSocials, () => open(c, EditProfile(store: store))),
              _checkItem(c, 'Способ оплаты', hasCard, () => open(c, DemoCardPage(store: store))),
            ]),
          );
        },
      );

  Widget _checkItem(BuildContext c, String title, bool isDone, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? mint : border, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: isDone ? ink : secondary),
                  ),
                ),
                const Icon(Icons.chevron_right, color: secondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileProgressCard extends StatelessWidget {
  final int percent;
  const _ProfileProgressCard({required this.percent});

  @override
  Widget build(BuildContext c) => Box(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist_rtl, color: ink, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Заполнение профиля', maxLines: 2, style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
                ),
                const SizedBox(width: 8),
                Text('$percent%', style: const TextStyle(fontWeight: FontWeight.w800, color: red)),
              ],
            ),
            space(10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 8,
                backgroundColor: peach,
                valueColor: const AlwaysStoppedAnimation(red),
              ),
            ),
            space(8),
            hint('Заполните профиль, чтобы заказы оформлялись быстрее. Нажмите сюда.'),
          ],
        ),
      );
}

class _AccountSection extends StatelessWidget {
  final Store store;
  const _AccountSection({required this.store});

  @override
  Widget build(BuildContext c) {
    if (store.accountEmail == null) {
      return Box(
        child: _FilledTile(
          icon: Icons.login,
          iconBg: mint,
          title: 'Войти или зарегистрироваться',
          subtitle: 'Синхронизация заказов и данных',
          onTap: () => open(c, AuthPage(store: store)),
        ),
      );
    }
    return Box(
      child: Column(
        children: [
          _FilledTile(
            icon: Icons.manage_accounts_outlined,
            iconBg: peach,
            title: 'Личные данные и соцсети',
            subtitle: 'Имя, телефон, адрес, ссылки',
            onTap: () => open(c, EditProfile(store: store)),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _MiniBankCard(store: store),
          ),
          const Divider(height: 1),
          _FilledTile(
            icon: Icons.logout,
            iconBg: blue,
            title: 'Выйти из аккаунта',
            subtitle: 'Данные останутся на устройстве',
            onTap: () async {
              try {
                await store.storage.logout();
                store.setAccount(null);
              } catch (_) {
                if (c.mounted) message(c, 'Не удалось выйти. Попробуйте ещё раз.');
              }
            },
          ),
          const Divider(height: 1),
          _FilledTile(
            icon: Icons.person_remove_outlined,
            iconBg: pink,
            title: 'Удалить аккаунт',
            subtitle: 'Проекты и заказы будут удалены',
            onTap: () => _confirmDelete(c),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext c) async {
    final ok = await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text('Будут удалены аккаунт, профиль, проекты, фотографии и история заказов.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await store.deleteCurrentAccountData();
    } catch (_) {
      if (c.mounted) message(c, 'Не удалось удалить аккаунт.');
    }
  }
}

class _MiniBankCard extends StatelessWidget {
  final Store store;
  const _MiniBankCard({required this.store});

  @override
  Widget build(BuildContext c) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => open(c, DemoCardPage(store: store)),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: blueGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x14cfdde7), blurRadius: 20, offset: Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.credit_card, color: ink),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), borderRadius: BorderRadius.circular(8)),
                      child: const Text('КАРТА', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ink, letterSpacing: 1)),
                    ),
                  ],
                ),
                space(16),
                Text(
                  store.cardLast4.isEmpty ? '•••• •••• •••• ••••' : '•••• •••• •••• ${store.cardLast4}',
                  style: const TextStyle(fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.w700, color: ink),
                ),
                space(8),
                Text(
                  store.cardLast4.isEmpty ? 'Способ оплаты не добавлен' : 'Привязанная карта',
                  style: const TextStyle(fontSize: 12, color: secondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DataSection extends StatelessWidget {
  final Store store;
  const _DataSection({required this.store});

  @override
  Widget build(BuildContext c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Box(
            child: Row(
              children: [
                Icon(Icons.smartphone_outlined, color: ink, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Фото, проекты и заказы хранятся на этом устройстве.', style: TextStyle(fontSize: 13, color: secondary)),
                ),
              ],
            ),
          ),
          space(12),
          Primary(
            'Очистить текущий проект',
            outline: true,
            onTap: store.photos.isEmpty
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: c,
                      builder: (d) => AlertDialog(
                        title: const Text('Очистить фотографии?'),
                        content: const Text('Фотографии удалятся из текущего проекта. Сохранённые проекты и заказы останутся нетронутыми.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Отмена')),
                          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Удалить')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await store.clearPhotos();
                      if (c.mounted) message(c, store.saveFailed ? 'Не удалось сохранить изменения' : 'Проект очищен');
                    }
                  },
          ),
        ],
      );
}

class _FilledTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _FilledTile({required this.icon, required this.iconBg, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext c) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: ink, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: ink, fontSize: 14)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: secondary)),
        trailing: const Icon(Icons.chevron_right, color: secondary),
        onTap: onTap,
      );
}

// ============================================================
//                      ПОДДЕРЖКА (ЧАТ)
// ============================================================

class Support extends StatefulWidget {
  final Store store;
  final String? orderId;
  const Support({super.key, required this.store, this.orderId});
  @override
  State<Support> createState() => _SupportState();
}

class _SupportState extends State<Support> {
  final text = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (widget.store.accountEmail == null) {
      message(context, 'Для обращения войдите в аккаунт.');
      return;
    }
    final value = text.text.trim();
    if (value.length < 3 || value.length > 1000) {
      message(context, 'Введите сообщение от 3 до 1000 символов.');
      return;
    }
    final store = widget.store;
    setState(() => busy = true);
    try {
      await store.sendSupportMessage(value, orderId: widget.orderId);
      if (mounted) text.clear();
    } catch (e) {
      if (mounted) message(context, 'Ошибка сети: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => StoreBuilder(
        animation: widget.store,
        builder: (c, _) {
          // МАППИНГ ДАННЫХ ИЗ SUPABASE В ФОРМАТ ChatTranscript
          final rawEntries = widget.store.supportMessages
              .where((m) => m['user_email'] == widget.store.accountEmail && (m['order_id'] ?? '') == (widget.orderId ?? ''))
              .toList();
              
          final entries = rawEntries.map((m) => {
            'text': m['text_content'] ?? '',
            'sender': m['sender'] ?? 'Вы',
            'time': m['created_at'] ?? DateTime.now().toIso8601String(),
          }).toList();

          return Scaffold(
            appBar: AppBar(
                title: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Поддержка'),
              Text(widget.orderId == null ? 'Чат с оператором' : 'Заказ ${widget.orderId}',
                  style: const TextStyle(fontSize: 11, color: secondary, fontWeight: FontWeight.normal)),
            ])),
            body: Container(
                color: const Color(0xffe9f0ec),
                child: widget.store.accountEmail == null
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Primary('Войти в аккаунт', onTap: () async {
                              await requireAccount(c, widget.store);
                            })))
                    : Column(children: [
                        Expanded(child: ChatTranscript(entries: entries)),
                        ChatComposer(controller: text, label: 'Сообщение', button: 'Отправить', busy: busy, send: send),
                      ])),
          );
        },
      );
}