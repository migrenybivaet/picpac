part of '../main.dart';

class MainTabs extends StatefulWidget {
  final Store store;
  final int initial;
  const MainTabs({super.key, required this.store, this.initial = 0});
  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  late int current;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    current = widget.initial;
    _pageController = PageController(initialPage: current);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => StoreBuilder(
        animation: widget.store,
        builder: (c, _) => Scaffold(
          extendBody: true,
          appBar: AppBar(
            title: const PicPacBrand(),
            centerTitle: false,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                tooltip: 'Уведомления',
                onPressed: () => open(c, NotificationsPage(store: widget.store)),
                icon: Badge(
                  isLabelVisible: widget.store.unreadCount > 0,
                  backgroundColor: red,
                  label: Text('${widget.store.unreadCount}'),
                  child: const Icon(Icons.notifications_none_outlined),
                ),
              ),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(gradient: softGradient),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (widget.store.saveFailed)
                    Container(
                      width: double.infinity,
                      color: pink,
                      padding: const EdgeInsets.all(8),
                      child: const Text('Не удалось сохранить данные.', textAlign: TextAlign.center),
                    ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => current = i),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        Catalog(store: widget.store),
                        Projects(store: widget.store),
                        Orders(store: widget.store),
                        Profile(store: widget.store),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Color(0x14263a35), blurRadius: 20, offset: Offset(0, 8))],
                ),
                child: NavigationBar(
                  height: 68,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  indicatorColor: peach,
                  selectedIndex: current,
                  onDestinationSelected: (i) {
                    setState(() => current = i);
                    _pageController.animateToPage(i, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
                  },
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Главная'),
                    NavigationDestination(icon: Icon(Icons.collections_bookmark_outlined), label: 'Проекты'),
                    NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Заказы'),
                    NavigationDestination(icon: Icon(Icons.person_outline), label: 'Профиль'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class Catalog extends StatefulWidget {
  final Store store;
  const Catalog({super.key, required this.store});

  @override
  State<Catalog> createState() => _CatalogState();
}

class _CatalogState extends State<Catalog> with TickerProviderStateMixin {
  late AnimationController _heroController;
  late AnimationController _listController;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _listFade;
  late Animation<Offset> _listSlide;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _heroFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOut));
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOutBack));

    _listController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _listFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _listController, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));
    _listSlide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _listController, curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack)));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _listController.forward();
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<bool> _startFresh(BuildContext c) async {
    if (widget.store.photos.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: c,
        builder: (d) => AlertDialog(
          title: const Text('Создать новый проект?'),
          content: const Text('Текущий проект сохранится. Новый проект начнётся без фотографий.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Отмена')),
            TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Создать')),
          ],
        ),
      );
      if (ok != true || !c.mounted) return false;
    }
    widget.store.startNewProject();
    return true;
  }

  Future<void> selectProduct(BuildContext c, int index) async {
    if (!await _startFresh(c) || !c.mounted) return;
    widget.store.productIndex = index;
    widget.store.changed();
    await open(c, ProductPage(store: widget.store));
  }

  @override
  Widget build(BuildContext c) => scroll([
        space(4),
        FadeTransition(
          opacity: _heroFade,
          child: SlideTransition(
            position: _heroSlide,
            child: _AnimatedHero(store: widget.store, onTap: () => selectProduct(c, 0)),
          ),
        ),
        space(24),
        FadeTransition(
          opacity: _listFade,
          child: SlideTransition(
            position: _listSlide,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                section('Книги и фотокниги'),
                space(12),
                SizedBox(
                  height: 250,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: products.where((p) => p.id != 'photo' && p.id != 'digital').length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (c, i) {
                      final list = products.where((p) => p.id != 'photo' && p.id != 'digital').toList();
                      final p = list[i];
                      return _LargeProductCard(
                        product: p,
                        onTap: () => selectProduct(c, products.indexOf(p)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        space(24),
        FadeTransition(
          opacity: _listFade,
          child: SlideTransition(
            position: _listSlide,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                section('Быстрая печать'),
                space(12),
                _GlassBanner(
                  title: 'От фото до заказа — проще',
                  subtitle: 'Выберите снимки и формат, затем сразу перейдите к оформлению.',
                  icon: Icons.bolt_rounded,
                  color: mint,
                  onTap: () => selectProduct(c, 1),
                ),
              ],
            ),
          ),
        ),
        space(60),
      ]);
}

class _AnimatedHero extends StatefulWidget {
  final Store store;
  final VoidCallback onTap;
  const _AnimatedHero({required this.store, required this.onTap});
  @override
  State<_AnimatedHero> createState() => _AnimatedHeroState();
}

class _AnimatedHeroState extends State<_AnimatedHero> with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -4, end: 4).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: mintGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x14c4dad6), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _floatAnim,
              builder: (context, child) => Positioned(
                right: -15, top: 10 + _floatAnim.value,
                child: Transform.rotate(
                  angle: -0.1,
                  child: Container(
                    width: 85, height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.8)),
                      boxShadow: [BoxShadow(color: ink.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: const Icon(Icons.photo_outlined, color: ink, size: 40),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _floatAnim,
              builder: (context, child) => Positioned(
                right: 45, bottom: -25 - _floatAnim.value,
                child: Transform.rotate(
                  angle: 0.15,
                  child: Container(
                    width: 75, height: 95,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.7)),
                      boxShadow: [BoxShadow(color: ink.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: const Icon(Icons.auto_stories_outlined, color: ink, size: 35),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('СОЗДАЙТЕ ЧТО-ТО ВЕЧНОЕ', style: TextStyle(color: secondary, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2)),
                space(8),
                const Text('Ваши лучшие моменты\nна бумаге', style: TextStyle(fontSize: 24, height: 1.15, fontWeight: FontWeight.w800, color: ink)),
                space(16),
                SizedBox(
                  width: 170,
                  child: Primary('Начать печать', onTap: widget.onTap),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;
  const _LargeProductCard({required this.product, required this.onTap});

  @override
  State<_LargeProductCard> createState() => _LargeProductCardState();
}

class _LargeProductCardState extends State<_LargeProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.product.color.withOpacity(_pressed ? 0.1 : 0.2), 
                blurRadius: _pressed ? 8 : 20, 
                offset: Offset(0, _pressed ? 2 : 10),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: widget.product.color.withOpacity(0.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(child: Icon(widget.product.icon, size: 56, color: ink)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.leadTime,
                      style: TextStyle(color: Color.lerp(widget.product.color, Colors.black, 0.6), fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    space(6),
                    Text(
                      widget.product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 16),
                    ),
                    space(8),
                    Text('от ${money(widget.product.priceKopecks)}', style: const TextStyle(fontWeight: FontWeight.w600, color: secondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassBanner extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GlassBanner({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: color.withOpacity(0.4), shape: BoxShape.circle),
                child: Icon(icon, color: ink, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
                    space(4),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: secondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward, color: ink, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductPage extends StatelessWidget {
  final Store store;
  const ProductPage({super.key, required this.store});

  @override
  Widget build(BuildContext c) => StoreBuilder(
        animation: store,
        builder: (c, _) => PageShell(
          store: store,
          title: store.product.title,
          bottom: Primary(
            store.configurable ? 'Добавить фотографии' : 'Пока недоступно',
            onTap: store.configurable ? () => open(c, PhotosPage(store: store)) : null,
          ),
          child: scroll([
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(store.product.color, Colors.white, .35)!, store.product.color],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 160,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), borderRadius: BorderRadius.circular(20)),
                      child: Icon(store.product.icon, size: 40, color: ink),
                    ),
                    space(10),
                    Text(store.product.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            space(20),
            h1(store.product.title),
            space(8),
            hint(store.product.description),
            space(24),
            
            // НОВЫЕ ФОРМАТЫ (ВЫВОДЯТСЯ ЧИПСАМИ)
            section('Формат'),
            space(8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: List.generate(
                store.formats.length,
                (i) => ChoiceChip(
                  label: Text(store.formats[i]),
                  selected: store.formatIndex == i,
                  onSelected: (_) { store.formatIndex = i; store.changed(); },
                ),
              ),
            ),
            
            if (store.isBook) ...[
              space(18),
              section(store.product.id == 'lite' ? 'Количество страниц' : 'Количество разворотов'),
              space(8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: List.generate(
                  store.pageOptions.length,
                  (i) => ChoiceChip(
                    label: Text(store.pageOptions[i]),
                    selected: store.pageIndex == i,
                    onSelected: (_) { store.pageIndex = i; store.changed(); },
                  ),
                ),
              ),
            ],
            space(20),
            hint('Условная цена: ${money(store.unitPrice)}${store.isPrint ? ' за снимок' : ''}.'),
          ]),
        ),
      );
}