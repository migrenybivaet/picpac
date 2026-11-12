part of '../main.dart';

// Замените функцию open на эту:
Future<T?> open<T>(BuildContext c, Widget page) => Navigator.of(c).push<T>(
      PageRouteBuilder<T>(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          // Более плавная пружинистая анимация
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.fastOutSlowIn, 
            reverseCurve: Curves.easeIn,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(.05, 0), end: Offset.zero).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );

/// Как AnimatedBuilder, но пока поверх экрана открыт другой маршрут
/// (редактор, диалог и т.п.), закрытый экран не перестраивается при каждом
/// изменении Store, а возвращает прошлый результат. Когда маршрут снова
/// становится текущим, экран перестраивается с актуальными данными.
class StoreBuilder extends StatefulWidget {
  final Listenable animation;
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;
  const StoreBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });
  @override
  State<StoreBuilder> createState() => _StoreBuilderState();
}

class _StoreBuilderState extends State<StoreBuilder> {
  Widget? _last;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.animation,
        child: widget.child,
        builder: (c, child) {
          final route = ModalRoute.of(c);
          final covered = route != null && !route.isCurrent;
          if (covered && _last != null) return _last!;
          return _last = widget.builder(c, child);
        },
      );
}

void showMain(BuildContext c, Store store, int tab) =>
    Navigator.of(c).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainTabs(store: store, initial: tab),
      ),
      (_) => false,
    );

void message(BuildContext c, String text) =>
    ScaffoldMessenger.of(c).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: ink,
        elevation: 6,
      ),
    );

Widget space([double h = 16]) => SizedBox(height: h);

Widget h1(String text) => Text(
      text,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: ink,
        height: 1.14,
        letterSpacing: -.4,
      ),
    );

Widget section(String text) => Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -.2,
      ),
    );

Widget hint(String text) => Text(
      text,
      style: const TextStyle(color: secondary, fontSize: 13, height: 1.45),
    );

Widget scroll(List<Widget> children) => Builder(
      builder: (c) {
        // Высота floating-навбара + безопасная зона + запас,
        // чтобы последний элемент не уходил под бар.
        final bottom = 96 +
            MediaQuery.paddingOf(c).bottom +
            MediaQuery.viewInsetsOf(c).bottom;
        return ListView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
          physics: const AlwaysScrollableScrollPhysics(),
          clipBehavior: Clip.none,
          children: children,
        );
      },
    );

// -------- Мягкие градиентные фоны (без неона) --------
const softGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xfffaf7f7), Color(0xfff3ecea)],
);

const peachGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xfff3e6da), Color(0xffeee0d3)],
);

const mintGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xffd6e8e2), Color(0xffc4dad6)],
);

const blueGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xffdbe7ef), Color(0xffcfdde7)],
);

const pinkGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xfff3dede), Color(0xffedd5d5)],
);

/// Полупрозрачный «жидкий» градиент для блюра
const glassGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xccffffff), Color(0x99ffffff)],
);

// -------- Glass-контейнер (жидкое стекло) --------
class GlassBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color tint;
  final bool border;
  const GlassBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.blur = 18,
    this.tint = const Color(0x66ffffff),
    this.border = true,
  });

  @override
  Widget build(BuildContext c) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(radius),
            border: border
                ? Border.all(
                    color: Colors.white.withValues(alpha: .7), width: 1)
                : null,
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      );
}

// -------- «Box» — мягкая карточка с лёгким градиентом и тенью --------
class Box extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  const Box({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext c) {
    final tinted = color != Colors.white;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: tinted
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(color, Colors.white, .25)!, color],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xfffdfbfb)],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tinted ? color : border.withValues(alpha: .7),
        ),
        boxShadow: tinted
            ? null
            : const [
                BoxShadow(
                  color: Color(0x11263a35),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
                BoxShadow(
                  color: Color(0x08263a35),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

// -------- Кнопка Primary: мягкий градиент + тень --------
class Primary extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool outline;
  const Primary(
    this.text, {
    super.key,
    required this.onTap,
    this.outline = false,
  });

  @override
  Widget build(BuildContext c) => SizedBox(
        width: double.infinity,
        height: 52,
        child: outline
            ? OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: red,
                  backgroundColor: Colors.white.withValues(alpha: .5),
                  side:
                      BorderSide(color: red.withValues(alpha: .55), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color.lerp(red, Colors.white, .12)!, red],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: red.withValues(alpha: .28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
      );
}

Widget totals(String a, String b, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              a,
              style: TextStyle(
                color: strong ? ink : secondary,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              b,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: ink,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

// -------- PageShell с градиентным фоном и стеклянным appbar --------
class PageShell extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? bottom;
  final List<Widget>? actions;
  final Store store;
  const PageShell({
    super.key,
    required this.title,
    required this.child,
    required this.store,
    this.bottom,
    this.actions,
  });

  @override
  Widget build(BuildContext c) => Scaffold(
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          title: Text(title),
          actions: actions,
          flexibleSpace: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bg.withValues(alpha: .92), bg.withValues(alpha: .72)],
              ),
            ),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(gradient: softGradient),
          child: SafeArea(
            child: Column(
              children: [
                StoreBuilder(
                  animation: store,
                  builder: (_, __) => store.saveFailed
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          color: pink,
                          child: const Text(
                            'Не удалось сохранить данные на устройстве.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
        bottomNavigationBar: bottom == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: bottom,
                ),
              ),
      );
}

Future<bool> requireAccount(BuildContext c, Store store) async {
  if (store.accountEmail != null) return true;
  final signedIn = await open<bool>(
    c,
    AuthPage(store: store, returnToPrevious: true),
  );
  return signedIn == true && store.accountEmail != null;
}

// -------- Бренд --------
class PicPacBrand extends StatelessWidget {
  const PicPacBrand({super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xffe57f7f), red],
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: red.withValues(alpha: .25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.photo_camera_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 9),
          const Text(
            'picPac',
            style: TextStyle(
              fontSize: 21,
              color: ink,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
        ],
      );
}

// -------- Декоративное пятно фона (без неона) --------
class SoftBlob extends StatelessWidget {
  final Color color;
  final double size;
  final Alignment alignment;
  const SoftBlob({
    super.key,
    required this.color,
    this.size = 260,
    this.alignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext c) => Align(
        alignment: alignment,
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: .55),
                  color.withValues(alpha: 0)
                ],
              ),
            ),
          ),
        ),
      );
}
