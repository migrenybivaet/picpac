part of '../main.dart';

class CheckPage extends StatelessWidget {
  final Store store;
  const CheckPage({super.key, required this.store});

  @override
  Widget build(BuildContext c) => StoreBuilder(
        animation: store,
        builder: (c, _) => PageShell(
          store: store,
          title: 'Проверка проекта',
          bottom: Primary(
            store.lowCount > 0 ? 'Продолжить с этими фото' : 'В корзину',
            onTap: store.photos.isEmpty
                ? null
                : () {
                    store.inCart = true;
                    store.changed();
                    open(c, Cart(store: store));
                  },
          ),
          child: scroll([
            h1('Проверка фотографий'),
            space(8),
            hint('Проверено файлов: ${store.photos.length}.'),
            space(20),
            Box(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline, color: ink),
                    title: const Text('Формат файлов'),
                    subtitle: const Text('Проверен при добавлении'),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      store.lowCount == 0 ? Icons.check_circle_outline : Icons.error_outline,
                      color: store.lowCount == 0 ? ink : red,
                    ),
                    title: Text(store.lowCount == 0 ? 'Разрешение подходит' : 'Низкое разрешение: ${store.lowCount}'),
                    subtitle: const Text('Ориентир: от 1600 × 1600 px'),
                  ),
                ],
              ),
            ),
            if (store.isBook && store.emptyBookSlots > 0) ...[
              space(16),
              Box(
                color: peach,
                child: Text('Пустых ячеек в книге: ${store.emptyBookSlots}. Добавьте фотографии или оставьте страницы пустыми.'),
              ),
            ],
            if (store.isBook && store.unplacedBookPhotos > 0) ...[
              space(16),
              Box(
                color: pink,
                child: Text('Не помещаются в выбранные развороты: ${store.unplacedBookPhotos} фото. Выберите макеты с большим количеством ячеек.'),
              ),
            ],
            space(12),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Вернуться в редактор'),
            ),
          ]),
        ),
      );
}

class Cart extends StatefulWidget {
  final Store store;
  const Cart({super.key, required this.store});
  @override
  State<Cart> createState() => _CartState();
}

class _CartState extends State<Cart> {
  final code = TextEditingController();
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => StoreBuilder(
        animation: widget.store,
        builder: (c, _) {
          final s = widget.store;
          return PageShell(
            store: s,
            title: 'Корзина',
            bottom: s.inCart
                ? Primary(
                    'Оформить · ${money(s.subtotal)}',
                    onTap: s.photos.isEmpty
                        ? null
                        : () async {
                            await open(c, Checkout(store: s));
                          },
                  )
                : null,
            child: scroll([
              h1('Корзина'),
              space(16),
              if (!s.inCart) ...[
                Box(
                  color: peach,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      section('Корзина пуста'),
                      space(6),
                      hint('Выберите продукт в каталоге.'),
                    ],
                  ),
                ),
                space(16),
                Primary('Перейти в каталог', onTap: () => showMain(c, s, 0)),
              ] else ...[
                Box(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      section(s.product.title),
                      space(6),
                      // Вывод формата
                      hint('Формат: ${s.format}'),
                      if (s.isBook) hint('Объем: ${s.pages} · ${s.paperFinish}'),
                      hint('Фотографий: ${s.photos.length}'),
                      space(8),
                      TextButton(
                        onPressed: () => open(c, Editor(store: s)),
                        child: const Text('Редактировать'),
                      ),
                      Row(
                        children: [
                          const Expanded(child: Text('Количество')),
                          IconButton(
                            onPressed: s.quantity > 1
                                ? () { s.quantity--; s.changed(); }
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('${s.quantity}'),
                          IconButton(
                            onPressed: s.quantity < 99
                                ? () { s.quantity++; s.changed(); }
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                space(14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: code,
                        decoration: const InputDecoration(labelText: 'Промокод'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        s.promo = code.text.trim().toUpperCase() == 'PIC10';
                        s.changed();
                        message(c, s.promo ? 'Промокод применён' : 'Промокод не найден');
                      },
                      child: const Text('Применить'),
                    ),
                  ],
                ),
                space(16),
                GlassBox(
                  radius: 18,
                  blur: 12,
                  child: Column(
                    children: [
                      totals('Товары', money(s.itemsPrice)),
                      if (s.promo) totals('Скидка PIC10', '−${money(s.discount)}'),
                      totals('Доставка', 'При оформлении'),
                      const Divider(),
                      totals('Итого', money(s.subtotal), strong: true),
                    ],
                  ),
                ),
                space(10),
                hint('Цены и промокод демонстрационные.'),
                TextButton(
                  onPressed: () { s.inCart = false; s.changed(); },
                  child: const Text('Удалить из корзины'),
                ),
              ],
            ]),
          );
        },
      );
}

class Checkout extends StatefulWidget {
  final Store store;
  const Checkout({super.key, required this.store});
  @override
  State<Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends State<Checkout> {
  final name = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController();
  @override
  void initState() {
    super.initState();
    name.text = widget.store.profileName;
    phone.text = widget.store.profilePhone;
    address.text = widget.store.profileAddress;
  }

  bool confirmed = false, placing = false;
  String payment = 'При получении';
  
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> place() async {
    final s = widget.store;
    if (!s.inCart || s.photos.isEmpty) {
      message(context, 'Для заказа нужен проект с фотографиями.');
      return;
    }
    final customer = name.text.trim(),
        number = phone.text.trim(),
        destination = address.text.trim();
        
    // Валидация полей
    final problem = fullNameError(customer) ??
        phoneError(number) ??
        (s.delivery == 'Курьер' ? addressError(destination) : null);
    if (problem != null) {
      message(context, problem);
      return;
    }
    
    if (!confirmed || placing) return;
    
    // Включаем состояние загрузки
    setState(() => placing = true);

    try {
      await s.createOrder(
        customerName: customer,
        phone: number,
        address: s.delivery == 'Курьер' ? destination : '',
        payment: payment == 'Карта' ? 'Оплачено' : 'При получении',
      );
      
      if (!mounted) return;
      
      // После успешного создания переходим на экран заказов
      Navigator.pop(context);
      showMain(context, s, 2);
      message(context, 'Заказ отправлен в облако!');
      
    } on NetworkException catch (e) {
      if (mounted) message(context, e.message);
    } catch (e) {
      if (mounted) message(context, 'Не удалось создать заказ. Проверьте интернет.');
    } finally {
      // ВСЕГДА снимаем блокировку, чтобы можно было попробовать снова
      if (mounted) setState(() => placing = false);
    }
  }

  @override
  Widget build(BuildContext c) => StoreBuilder(
        animation: widget.store,
        builder: (c, _) {
          final s = widget.store;
          return PageShell(
            store: s,
            title: 'Оформление',
            bottom: Primary(
              placing ? 'Отправка...' : 'Оформить заказ',
              onTap: confirmed && !placing ? place : null,
            ),
            child: scroll([
              h1('Оформление'),
              space(10),
              Box(
                color: blue,
                child: hint('Заказ отправится на сервер, и его увидит администратор.'),
              ),
              space(20),
              section('1. Контакты'),
              space(10),
              TextField(
                controller: name,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'ФИО'),
              ),
              space(10),
              TextField(
                controller: phone,
                maxLength: 24,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Телефон'),
              ),
              space(20),
              section('2. Получение'),
              space(8),
              Box(
                child: Column(
                  children: ['Курьер', 'Самовывоз']
                      .map(
                        (v) => RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          value: v,
                          groupValue: s.delivery,
                          onChanged: (v) { s.delivery = v!; s.changed(); },
                          title: Text(v),
                          subtitle: Text(v == 'Курьер' ? '5,00 BYN' : 'Бесплатно'),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (s.delivery == 'Курьер') ...[
                space(10),
                TextField(
                  controller: address,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Адрес доставки'),
                ),
              ],
              space(18),
              section('3. Оплата'),
              space(8),
              Box(
                child: Column(
                  children: [
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('При получении'),
                      value: 'При получении',
                      groupValue: payment,
                      onChanged: placing ? null : (v) => setState(() => payment = v!),
                    ),
                  ],
                ),
              ),
              space(14),
              GlassBox(
                radius: 18,
                blur: 10,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  children: [
                    totals('Товары', money(s.subtotal)),
                    if (s.isBook) totals('Отделка', s.paperFinish),
                    totals('Доставка', money(s.deliveryPrice)),
                    const Divider(),
                    totals('Итого', money(s.subtotal + s.deliveryPrice), strong: true),
                  ],
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: confirmed,
                onChanged: (v) => setState(() => confirmed = v ?? false),
                title: const Text('Подтверждаю оформление заказа', style: TextStyle(fontSize: 13)),
              ),
            ]),
          );
        },
      );
}

class OrderDetail extends StatelessWidget {
  final Store store;
  final Map<String, dynamic> order;
  const OrderDetail({super.key, required this.store, required this.order});

  @override
  Widget build(BuildContext c) => PageShell(
        store: store,
        title: 'Детали заказа',
        bottom: Primary('К заказам', onTap: () => showMain(c, store, 2)),
        child: scroll([
          Box(
            color: mint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                section('Заказ оформлен'),
                space(6),
                hint('Он отправлен администратору в облако.'),
              ],
            ),
          ),
          space(20),
          section('Состав заказа'),
          space(8),
          Box(
            child: Column(
              children: [
                totals('Номер', order['id'].toString()),
                totals('Продукт', order['product'].toString()),
                totals('Покупатель', order['customer_name']?.toString() ?? 'Гость'),
                if (order['phone'] != null && (order['phone'] as String).isNotEmpty)
                  totals('Телефон', order['phone'].toString()),
                if (order['address'] != null && (order['address'] as String).isNotEmpty)
                  totals('Адрес', order['address'].toString()),
                const Divider(),
                totals('Итого', money((order['total'] as num).toInt()), strong: true),
              ],
            ),
          ),
          space(20),
          section('Статус'),
          space(8),
          Box(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OrderTimeline(status: '${order['status'] ?? 'Принят'}'),
              ],
            ),
          ),
        ]),
      );
}

class Orders extends StatelessWidget {
  final Store store;
  const Orders({super.key, required this.store});

  @override
  Widget build(BuildContext c) => StoreBuilder(
        animation: store,
        builder: (c, _) => scroll([
          space(4),
          h1('Мои заказы'),
          space(7),
          hint('История заказов, синхронизированная с сервером.'),
          space(18),
          if (store.accountEmail == null)
            Primary('Войти, чтобы увидеть заказы', onTap: () async { await requireAccount(c, store); })
          else if (store.myOrders.isEmpty)
            const Box(color: peach, child: Text('Заказов пока нет.'))
          else
            ...store.myOrders.map(
              (o) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Box(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      section(o['product'].toString()),
                      space(4),
                      hint('${o['id']} · ${o['status'] ?? 'Принят'}'),
                      space(6),
                      TextButton(
                        onPressed: () => open(c, OrderDetail(store: store, order: o)),
                        child: const Text('Подробнее'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ]),
      );
}

class OrderTimeline extends StatelessWidget {
  final String status;
  const OrderTimeline({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final stages = Store.orderStages;
    final current = stages.indexOf(status);
    
    // Если статус из облака не совпал (например, "Производство"), 
    // находим его в списке или ставим 0
    final activeIndex = current == -1 ? 0 : current;

    return Column(
      children: [
        for (var i = 0; i < stages.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= activeIndex ? red : Colors.white,
                          border: Border.all(color: i <= activeIndex ? red : border, width: 2),
                        ),
                        child: i < activeIndex
                            ? const Icon(Icons.check, size: 13, color: Colors.white)
                            : i == activeIndex
                                ? Center(
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    ),
                                  )
                                : null,
                      ),
                      if (i < stages.length - 1)
                        Expanded(
                          child: Container(width: 2, color: i < activeIndex ? red : border),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i < stages.length - 1 ? 14 : 0),
                    child: Text(
                      stages[i],
                      style: TextStyle(
                        fontWeight: i == activeIndex ? FontWeight.w800 : FontWeight.w500,
                        color: i <= activeIndex ? ink : secondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}