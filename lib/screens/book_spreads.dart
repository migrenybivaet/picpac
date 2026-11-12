part of '../main.dart';

/// The book uses independent templates per page. Photo assignment remains
/// deterministic: fill each page in list order, left to right by spread.
class BookSpreadsPage extends StatelessWidget {
  final Store store;
  const BookSpreadsPage({super.key, required this.store});
  @override
  Widget build(BuildContext c) => PageShell(
        store: store,
        title: 'Развороты книги',
        bottom: Primary('Готово', onTap: () => Navigator.pop(c)),
        child: scroll([BookSpreadsPanel(store: store)]),
      );
}

class BookSpreadsPanel extends StatefulWidget {
  final Store store;
  const BookSpreadsPanel({super.key, required this.store});
  @override
  State<BookSpreadsPanel> createState() => _BookSpreadsPanelState();
}

class _BookSpreadsPanelState extends State<BookSpreadsPanel> {
  int current = 0;
  @override
  Widget build(BuildContext c) => StoreBuilder(
        animation: widget.store,
        builder: (c, _) {
          final s = widget.store;
          if (!s.isBook || s.spreadCount == 0) return const SizedBox.shrink();
          final spread = current.clamp(0, s.spreadCount - 1);
          final left = spread * 2;
          Widget page(int index, String label) {
            final layout = s.layoutForBookPage(index);
            return Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Страница ${index + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    space(6),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => open(
                          c, TemplatesPage(store: s, bookPageIndex: index)),
                      child: LayoutPreview(
                          store: s,
                          layout: layout,
                          start: s.bookPagePhotoStart(index),
                          aspectRatio: s.bookPageAspect),
                    ),
                    space(4),
                    TextButton(
                      onPressed: () => open(
                          c, TemplatesPage(store: s, bookPageIndex: index)),
                      child: Text(label, textAlign: TextAlign.center),
                    ),
                    Text(layout.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: secondary, fontSize: 12)),
                  ]),
            );
          }

          final reduceMotion = MediaQuery.disableAnimationsOf(c);
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                section('Развороты фотокниги'),
                space(6),
                hint(
                    'Выберите макет отдельно для каждой страницы. Фото размещаются по порядку списка.'),
                space(12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(
                      tooltip: 'Предыдущий разворот',
                      onPressed: spread > 0
                          ? () => setState(() => current = spread - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left)),
                  Expanded(
                      child: Text('Разворот ${spread + 1} из ${s.spreadCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                  IconButton(
                      tooltip: 'Следующий разворот',
                      onPressed: spread + 1 < s.spreadCount
                          ? () => setState(() => current = spread + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right)),
                ]),
                AnimatedSwitcher(
                  duration: Duration(milliseconds: reduceMotion ? 0 : 250),
                  transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                          scale: Tween<double>(begin: .97, end: 1)
                              .animate(animation),
                          child: child)),
                  child: Row(
                      key: ValueKey(spread),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        page(left, 'Макет слева'),
                        const SizedBox(width: 8),
                        page(left + 1, 'Макет справа'),
                      ]),
                ),
                space(8),
                hint(
                    'При смене макета фотографии могут сдвинуться на следующие страницы. Макет — локальный предпросмотр, не печатный файл.'),
                if (s.unplacedBookPhotos > 0) ...[
                  space(10),
                  Box(
                      color: pink,
                      child: Text(
                          'Не помещаются: ${s.unplacedBookPhotos} фото. Добавьте развороты или выберите макеты с большим количеством ячеек.')),
                ],
              ]);
        },
      );
}
