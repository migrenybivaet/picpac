part of '../main.dart';

enum NetworkMode { online, offline, lostResponse }

class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);
  @override
  String toString() => message;
}

class Store extends ChangeNotifier {
  final AppStorage storage;
  Store(this.storage) {
    _initSupabaseStreams();
  }

  StreamSubscription? _ordersSubscription;
  StreamSubscription? _supportSubscription;

  void _initSupabaseStreams() {
    try {
      _ordersSubscription = Supabase.instance.client
          .from('orders')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .listen((data) {
        for (final newOrder in data) {
          final oldOrder = orders.where((o) => o['id'] == newOrder['id']).firstOrNull;
          if (oldOrder != null && oldOrder['status'] != newOrder['status']) {
            if (newOrder['user_email'] == accountEmail || accountEmail == null) {
              NotificationService.show(
                'Статус заказа изменен',
                'Заказ ${newOrder['id']} теперь: ${newOrder['status']}',
              );
            }
          }
        }
        orders = data;
        notifyListeners();
      }, onError: (e) => debugPrint('Orders Stream Error: $e'));

      _supportSubscription = Supabase.instance.client
          .from('support_messages')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: true)
          .listen((data) {
        supportMessages = data;
        notifyListeners();
      }, onError: (e) => debugPrint('Support Stream Error: $e'));

    } catch (e) {
      debugPrint('Ошибка подключения к Supabase: $e');
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _supportSubscription?.cancel();
    super.dispose();
  }

  NetworkMode networkMode = NetworkMode.online;
  void setNetworkMode(NetworkMode mode) { networkMode = mode; notifyListeners(); }

  int productIndex = 0, formatIndex = 0, pageIndex = 0, quantity = 1;
  List<Photo> photos = [];
  Map<String, dynamic>? composition;
  String profileName = '', profileAddress = '', profilePhone = '', cardLast4 = '';
  Map<String, String> socialProfiles = {};
  List<Map<String, dynamic>> notifications = [], supportMessages = [];
  Map<String, Map<String, dynamic>> profiles = {};
  String? adminEmail, supportEmail;
  String paperFinish = 'Глянцевая';
  String? _orderKey;

  List<Map<String, dynamic>> get visibleNotifications => notifications.where((n) => n['owner'] == (accountEmail ?? '__guest__')).toList();
  List<Map<String, dynamic>> get myOrders => accountEmail == null ? [] : orders.where((o) => o['user_email'] == accountEmail).toList();

  void notifyLocal(String title, String body, {String? owner}) {
    notifications.insert(0, {
      'title': title, 'body': body, 'owner': owner ?? accountEmail ?? '__guest__',
      'read': false, 'time': DateTime.now().toIso8601String(),
    });
  }

  int get unreadCount => visibleNotifications.where((n) => n['read'] != true).length;
      
  static const orderStages = ['Принят', 'Модерация', 'Производство', 'Готов к выдаче', 'Доставлен / выдан', 'Завершён'];

  Future<void> sendSupportMessage(String text, {String? orderId}) async {
    if (accountEmail == null) throw StateError('Войдите в аккаунт');
    final msg = {
      'id': 'msg-${DateTime.now().microsecondsSinceEpoch}',
      'user_email': accountEmail,
      'order_id': orderId ?? '',
      'sender': 'Вы',
      'text_content': text,
      'created_at': DateTime.now().toIso8601String(),
    };
    try {
      await Supabase.instance.client.from('support_messages').insert(msg);
    } catch (e) {
      throw NetworkException('Ошибка сети при отправке сообщения: $e');
    }
  }

  Future<void> sendAdminReply(String owner, String text, {String? orderId}) async {
    final msg = {
      'id': 'msg-${DateTime.now().microsecondsSinceEpoch}',
      'user_email': owner,
      'order_id': orderId ?? '',
      'sender': 'Поддержка',
      'text_content': text,
      'created_at': DateTime.now().toIso8601String(),
    };
    try {
      await Supabase.instance.client.from('support_messages').insert(msg);
    } catch (e) {
      throw NetworkException('Ошибка сети при отправке ответа: $e');
    }
  }

  Future<void> adminSetOrderStatus(Map<String, dynamic> order, String status) async {
    if (adminEmail == null && await storage.adminState() == null) throw StateError('Нужен вход администратора');
    if (!orderStages.contains(status)) throw StateError('Некорректный статус');
    try {
      await Supabase.instance.client.from('orders').update({'status': status}).eq('id', order['id']);
    } catch (e) {
      throw StateError('Ошибка сети. Не удалось обновить статус.');
    }
  }

  void _saveProfile() {
    if (accountEmail == null) return;
    profiles[accountEmail!] = {
      'name': profileName, 'address': profileAddress, 'phone': profilePhone,
      'socials': Map<String, String>.from(socialProfiles), 'card': cardLast4,
    };
  }

  void _loadProfile() {
    final p = accountEmail == null ? null : profiles[accountEmail];
    profileName = p?['name'] as String? ?? '';
    profileAddress = p?['address'] as String? ?? '';
    profilePhone = p?['phone'] as String? ?? '';
    socialProfiles = p?['socials'] is Map ? (p!['socials'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())) : {};
    cardLast4 = p?['card'] as String? ?? '';
  }

  bool promo = false, inCart = false, saveFailed = false, needsReview = false;
  String delivery = 'Курьер';
  String? photoDirectory;
  String? accountEmail;
  
  Map<String, Map<String, dynamic>> draftBuckets = {};
  Map<String, dynamic>? unassignedLegacyDraft;
  String _activeWorkspace = 'guest';
  String _customerKey(String email) => 'user:${email.trim().toLowerCase()}';

  Map<String, dynamic> _currentDraft() => {
        'productKey': product.id, 'product': productIndex, 'format': formatIndex, 'pages': pageIndex, 'quantity': quantity, 'paperFinish': paperFinish, 'promo': promo, 'inCart': inCart, 'needsReview': needsReview, 'layout': layoutId, 'bookPageLayouts': bookPageLayouts.map((k, v) => MapEntry(k.toString(), v)), 'layoutMargin': layoutMargin, 'delivery': delivery, 'photos': photos.map((p) => p.toMap()).toList(), 'composition': composition, 'currentProjectId': currentProjectId, 'savedProjects': savedProjects,
      };
      
  Map<String, dynamic> _copy(Map<String, dynamic> value) => Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  
  void _stashDraft() { draftBuckets[_activeWorkspace] = _copy(_currentDraft()); }

  void _applyDraft(Map<String, dynamic>? m) {
    final d = m ?? <String, dynamic>{};
    final key = d['productKey'] as String?;
    final oldIndex = (d['product'] as num?)?.toInt() ?? 0;
    final found = products.indexWhere((p) => p.id == key);
    productIndex = key == null ? (oldIndex == 1 ? 1 : 0) : (found < 0 ? 0 : found);
    final oldCatalog = d.isNotEmpty && key == null;
    formatIndex = oldCatalog ? 0 : ((d['format'] as num?)?.toInt() ?? 0).clamp(0, formats.isEmpty ? 0 : formats.length - 1);
    pageIndex = ((d['pages'] as num?)?.toInt() ?? 0).clamp(0, 2);
    quantity = ((d['quantity'] as num?)?.toInt() ?? 1).clamp(1, 99);
    paperFinish = d['paperFinish'] as String? ?? 'Глянцевая';
    promo = d['promo'] == true;
    inCart = !oldCatalog && d['inCart'] == true;
    needsReview = oldCatalog || d['needsReview'] == true;
    delivery = d['delivery'] == 'Самовывоз' ? 'Самовывоз' : 'Курьер';
    final savedLayout = d['layout'] as String?;
    layoutId = layouts.any((l) => l.id == savedLayout) ? savedLayout! : 'single';
    bookPageLayouts = _readBookPageLayouts(d['bookPageLayouts']);
    layoutMargin = ((d['layoutMargin'] as num?)?.toDouble() ?? 0).clamp(0, 12);
    photos = (d['photos'] as List? ?? []).map((e) => Photo.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    composition = d['composition'] is Map ? Map<String, dynamic>.from(d['composition'] as Map) : null;
    currentProjectId = d['currentProjectId'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString();
    savedProjects = (d['savedProjects'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _switchDraft(String next, {bool transferGuestProject = false}) {
    final previous = _activeWorkspace;
    _stashDraft();
    final guest = previous == 'guest' && transferGuestProject ? _copy(draftBuckets['guest']!) : null;
    _activeWorkspace = next;
    _applyDraft(draftBuckets[next]);
    if (guest != null && next.startsWith('user:') && (guest['photos'] as List? ?? []).isNotEmpty) {
      _archiveCurrent();
      final targetSaved = _copy({'items': savedProjects})['items'] as List;
      final guestSaved = guest['savedProjects'];
      guest['savedProjects'] = targetSaved;
      _applyDraft(guest);
      draftBuckets['guest'] = {'savedProjects': guestSaved};
    }
    _stashDraft();
  }

  Future<void> claimLegacyDrafts() async {
    final owner = accountEmail;
    if (owner == null || unassignedLegacyDraft == null) throw StateError('Войдите в аккаунт');
    if (!await storage.verifyDeviceOwner() || accountEmail != owner) throw StateError('Подтвердите блокировку устройства');
    final legacy = _copy(unassignedLegacyDraft!);
    final previous = _copy(_currentDraft());
    _applyDraft(legacy);
    _archiveCurrent();
    final recovered = _copy({'items': savedProjects})['items'] as List;
    _applyDraft(previous);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < recovered.length; i++) {
      final project = Map<String, dynamic>.from(recovered[i] as Map);
      project['id'] = 'recovered-$timestamp-$i';
      savedProjects.add(project);
    }
    unassignedLegacyDraft = null;
    changed();
    await flush();
    if (saveFailed) {
      _applyDraft(previous);
      unassignedLegacyDraft = legacy;
      changed();
      throw StateError('Не удалось сохранить проекты');
    }
  }

  Future<void> deleteCurrentAccountData() async {
    final owner = accountEmail;
    if (owner == null) throw StateError('Войдите в аккаунт');
    await flush();
    if (saveFailed) throw StateError('Не удалось сохранить данные');
    _stashDraft();
    final old = _copy(_currentDraft());
    final ids = <String>{};
    void collect(dynamic list) {
      if (list is List) {
        for (final p in list) {
          if (p is Map && p['id'] is String) ids.add(p['id'] as String);
        }
      }
    }
    collect(old['photos']);
    for (final p in (old['savedProjects'] as List? ?? [])) {
      if (p is Map) collect(p['photos']);
    }
    draftBuckets.remove(_customerKey(owner));
    profiles.remove(owner);
    notifications.removeWhere((n) => n['owner'] == owner);
    supportMessages.removeWhere((m) => m['owner'] == owner);
    accountEmail = null;
    _activeWorkspace = 'guest';
    _applyDraft(draftBuckets['guest']);
    _loadProfile();
    changed();
    await flush();
    try { await storage.deleteAccount(); } catch (_) {}
    for (final id in ids) {
      if (!_isReferencedElsewhere(id)) {
        try { await storage.delete(id); } catch (_) {}
      }
    }
  }

  void setAccount(String? email, {bool transferGuestProject = false}) {
    _saveProfile();
    accountEmail = email;
    if (email != null) { adminEmail = null; supportEmail = null; }
    _switchDraft(email == null ? 'guest' : _customerKey(email), transferGuestProject: transferGuestProject);
    _loadProfile();
    changed();
  }

  void setAdmin(String? email) {
    _saveProfile();
    accountEmail = null;
    adminEmail = email;
    if (email != null) supportEmail = null;
    _switchDraft(email == null ? 'guest' : 'staff:admin');
    _loadProfile();
    changed();
  }

  void setSupport(String? email) {
    _saveProfile();
    accountEmail = null;
    adminEmail = null;
    supportEmail = email;
    _switchDraft(email == null ? 'guest' : 'staff:support');
    _loadProfile();
    changed();
  }

  String layoutId = 'single';
  Map<int, String> bookPageLayouts = {};
  
  Map<int, String> _readBookPageLayouts(Object? raw) {
    if (raw is! Map) return {};
    final result = <int, String>{};
    raw.forEach((key, value) {
      final i = int.tryParse(key.toString());
      if (i != null && i >= 0 && i < 200 && layouts.any((l) => l.id == value)) result[i] = value as String;
    });
    return result;
  }

  int get spreadCount {
    if (!isBook) return 0;
    final number = int.tryParse(pages.split(' ').first) ?? 0;
    return product.id == 'lite' ? (number / 2).ceil() : number;
  }

  int get bookPageCount => spreadCount * 2;
  
  double get bookPageAspect {
    final match = RegExp(r'(\d+)\s*×\s*(\d+)').firstMatch(format);
    if (match == null) return 1;
    final width = double.tryParse(match.group(1) ?? '') ?? 1;
    final height = double.tryParse(match.group(2) ?? '') ?? 1;
    return height > 0 ? (width / height).clamp(.4, 2.5) : 1;
  }

  BookLayout layoutForBookPage(int index) {
    final id = bookPageLayouts[index] ?? layoutId;
    return layouts.firstWhere((l) => l.id == id, orElse: () => layout);
  }

  void setBookPageLayout(int index, String id) {
    if (index < 0 || index >= bookPageCount || !layouts.any((l) => l.id == id)) return;
    bookPageLayouts[index] = id;
    changed();
  }

  int bookPagePhotoStart(int index) {
    var start = 0;
    for (var i = 0; i < index.clamp(0, bookPageCount); i++) { start += layoutForBookPage(i).slots; }
    return start;
  }

  int get unplacedBookPhotos => (photos.length - bookPagePhotoStart(bookPageCount)).clamp(0, photos.length);
  int get emptyBookSlots => (bookPagePhotoStart(bookPageCount) - photos.length).clamp(0, bookPagePhotoStart(bookPageCount));
  double layoutMargin = 0;
  BookLayout get layout => layouts.firstWhere((l) => l.id == layoutId, orElse: () => layouts.first);
  File? photoFile(Photo photo) => photoDirectory == null ? null : File('$photoDirectory/${photo.id}');
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> savedProjects = [];
  String currentProjectId = DateTime.now().microsecondsSinceEpoch.toString();
  Future<void> _queue = Future.value();
  
  Product get product => products[productIndex.clamp(0, products.length - 1)];
  bool get isBook => product.id == 'classic' || product.id == 'lite' || product.id == 'premium';
  bool get isPrint => product.id == 'photo' || product.id == 'digital';
  bool get configurable => true;
  
  List<String> get formats => product.formats.isNotEmpty ? product.formats : switch (product.id) {
    'photo' || 'digital' => ['10 × 15 см', '15 × 20 см', '20 × 30 см', 'A4 (21 × 30 см)', 'Панорама (20 × 60 см)'],
    'lite' => ['15 × 15 см (Мини)', '20 × 20 см', '21 × 30 см (А4)', '25 × 25 см'],
    'classic' => ['15 × 15 см (Мини)', '20 × 20 см', '21 × 30 см (А4)', '25 × 25 см', '30 × 30 см'],
    'premium' => ['20 × 20 см', '21 × 30 см (А4)', '25 × 25 см', '30 × 20 см', '30 × 30 см', '30 × 40 см (XXL)'],
    _ => <String>[],
  };
  
  String get format => formats.isEmpty ? 'Уточняется' : formats[formatIndex.clamp(0, formats.length - 1)];
  
  List<String> get pageOptions => product.pageOptions.isNotEmpty ? product.pageOptions : switch (product.id) {
    'lite' => ['24 страницы', '32 страницы', '40 страниц'],
    'classic' => ['10 разворотов', '15 разворотов', '20 разворотов'],
    'premium' => ['5 разворотов', '10 разворотов', '15 разворотов'],
    _ => <String>[],
  };
  
  String get pages => pageOptions.isEmpty ? '' : pageOptions[pageIndex.clamp(0, pageOptions.length - 1)];
  
  int get unitPrice {
    final base = product.priceKopecks;
    final formatExtra = formatIndex * (isPrint ? 60 : 2500);
    final pagesExtra = isBook ? pageIndex * 1000 : 0;
    return base + formatExtra + pagesExtra;
  }
  
  int get itemsPrice => unitPrice * quantity * (isPrint ? photos.length : 1);
  int get discount => promo ? (itemsPrice * 10 / 100).round() : 0;
  int get subtotal => itemsPrice - discount;
  int get deliveryPrice => delivery == 'Курьер' ? 500 : 0;
  int get lowCount => photos.where((p) => p.lowResolution).length;

  Future<void> load() async {
    try {
      photoDirectory = await storage.photoDirectory();
      accountEmail = await storage.authState();
      adminEmail = await storage.adminState();
      supportEmail = await storage.supportState();
      final text = await storage.load();
      if (text != null) {
        final m = jsonDecode(text) as Map<String, dynamic>;
        if (m['draftBuckets'] is Map) {
          draftBuckets = (m['draftBuckets'] as Map).map((key, value) => MapEntry(key.toString(), Map<String, dynamic>.from(value as Map)));
        }
        _applyDraft(draftBuckets[_activeWorkspace]);
        profileName = m['profileName'] as String? ?? '';
        profileAddress = m['profileAddress'] as String? ?? '';
        profilePhone = m['profilePhone'] as String? ?? '';
        socialProfiles = (m['socialProfiles'] is Map) ? (m['socialProfiles'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())) : {};
        cardLast4 = m['cardLast4'] as String? ?? '';
        if (m['profiles'] is Map) {
          profiles = (m['profiles'] as Map).map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)));
        }
        _loadProfile();
        notifications = (m['notifications'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        supportMessages = (m['supportMessages'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {
      saveFailed = true;
    }
  }

  String snapshot() {
    _stashDraft();
    return jsonEncode({
      'draftBuckets': draftBuckets, 'unassignedLegacyDraft': unassignedLegacyDraft, 'profiles': profiles,
      'profileName': profileName, 'profileAddress': profileAddress, 'profilePhone': profilePhone,
      'socialProfiles': socialProfiles, 'cardLast4': cardLast4, 'notifications': notifications,
    });
  }

  void changed() {
    _saveProfile();
    notifyListeners();
    final data = snapshot();
    _queue = _queue.then((_) => storage.save(data)).then((_) {
      if (saveFailed) { saveFailed = false; notifyListeners(); }
    }).catchError((Object e) {
      saveFailed = true;
      notifyListeners();
    });
  }

  Future<void> flush() => _queue;

  Future<Map<String, dynamic>> createOrder({String customerName = '', String phone = '', String address = '', String payment = 'При получении (тест)'}) async {
    if (!inCart || photos.isEmpty) throw StateError('Нельзя создать заказ без корзины и фотографий.');
    final order = <String, dynamic>{
      'id': 'PP-${DateTime.now().millisecondsSinceEpoch}', 'user_email': accountEmail ?? 'guest@picpac.local',
      'customer_name': customerName, 'phone': phone, 'address': address, 'product': product.title,
      'total': subtotal + deliveryPrice, 'status': 'Принят', 'created_at': DateTime.now().toIso8601String(),
    };
    try {
      await Supabase.instance.client.from('orders').insert(order);
    } catch (e) {
      debugPrint('SUPABASE REAL ERROR: $e');
      final errorMsg = e.toString().length > 150 ? e.toString().substring(0, 150) : e.toString();
      throw NetworkException('Ошибка: $errorMsg');
    }
    inCart = false;
    changed();
    return order;
  }

  Future<PickResult> addPhotos() async {
    final result = await storage.pick();
    photos.addAll(result.files);
    changed();
    return result;
  }

  Future<void> removePhoto(int index) async {
    final item = photos.removeAt(index);
    if (photos.isEmpty) composition = null;
    changed();
    await flush();
    if (!saveFailed) { try { await storage.delete(item.id); } catch (_) {} }
  }

  Future<void> clearPhotos() async {
    final old = List<Photo>.from(photos);
    photos.clear(); composition = null; inCart = false;
    changed();
    await flush();
    if (!saveFailed) { for (final p in old) { try { await storage.delete(p.id); } catch (_) {} } }
  }

  Map<String, dynamic> _projectSnapshot() => {
        'id': currentProjectId, 'productKey': product.id, 'formatIndex': formatIndex, 'pageIndex': pageIndex, 'quantity': quantity, 'paperFinish': paperFinish, 'layoutId': layoutId, 'bookPageLayouts': bookPageLayouts.map((k, v) => MapEntry(k.toString(), v)), 'layoutMargin': layoutMargin, 'photos': photos.map((p) => p.toMap()).toList(), 'composition': composition, 'needsReview': needsReview,
      };

  void _archiveCurrent() {
    if (photos.isEmpty) return;
    final copy = Map<String, dynamic>.from(jsonDecode(jsonEncode(_projectSnapshot())) as Map);
    savedProjects.removeWhere((p) => p['id'] == currentProjectId);
    savedProjects.insert(0, copy);
  }

  void startNewProject() {
    _archiveCurrent();
    currentProjectId = DateTime.now().microsecondsSinceEpoch.toString();
    photos = []; composition = null; inCart = false; promo = false; needsReview = false;
    productIndex = 0; formatIndex = 0; pageIndex = 0; quantity = 1; paperFinish = 'Глянцевая';
    layoutId = 'single'; bookPageLayouts = {}; layoutMargin = 0;
    changed();
  }

  void restoreProject(String id) {
    final matches = savedProjects.where((p) => p['id'] == id).toList();
    if (matches.isEmpty) return;
    final selected = matches.first;
    _archiveCurrent();
    savedProjects.removeWhere((p) => p['id'] == id);
    currentProjectId = id;
    final index = products.indexWhere((p) => p.id == selected['productKey']);
    productIndex = index < 0 ? 0 : index;
    formatIndex = ((selected['formatIndex'] as num?)?.toInt() ?? 0).clamp(0, formats.length - 1);
    pageIndex = ((selected['pageIndex'] as num?)?.toInt() ?? 0).clamp(0, 2);
    quantity = ((selected['quantity'] as num?)?.toInt() ?? 1).clamp(1, 99);
    paperFinish = selected['paperFinish'] as String? ?? 'Глянцевая';
    layoutId = layouts.any((l) => l.id == selected['layoutId']) ? selected['layoutId'] as String : 'single';
    bookPageLayouts = _readBookPageLayouts(selected['bookPageLayouts']);
    layoutMargin = ((selected['layoutMargin'] as num?)?.toDouble() ?? 0).clamp(0, 12);
    photos = (selected['photos'] as List? ?? []).map((p) => Photo.fromMap(Map<String, dynamic>.from(p as Map))).toList();
    composition = selected['composition'] is Map ? Map<String, dynamic>.from(selected['composition'] as Map) : null;
    inCart = false; promo = false; needsReview = selected['needsReview'] == true;
    changed();
  }

  bool _draftReferences(Map<String, dynamic> draft, String id) =>
      (draft['photos'] as List? ?? []).any((p) => p is Map && p['id'] == id) ||
      (draft['savedProjects'] as List? ?? []).any((project) => project is Map && (project['photos'] as List? ?? []).any((p) => p is Map && p['id'] == id));
      
  bool _isReferencedElsewhere(String id) =>
      draftBuckets.values.any((draft) => _draftReferences(draft, id)) ||
      (unassignedLegacyDraft != null && _draftReferences(unassignedLegacyDraft!, id)) ||
      orders.any((order) => (order['photoData'] as List? ?? []).any((p) => p is Map && p['id'] == id));

  bool orderPhotosAvailable(Map<String, dynamic> order) => true;

  Future<void> adminModerateOrder(Map<String, dynamic> order, String decision, String comment) async {
    if (adminEmail == null && await storage.adminState() == null) throw StateError('Нужен вход администратора.');
    try {
      await Supabase.instance.client.from('orders').update({
        'moderation': decision, 'moderation_comment': comment,
      }).eq('id', order['id']);
    } catch (_) {
      throw StateError('Не удалось сохранить решение.');
    }
  }

  void invalidateCompositionPreview() {
    if (composition == null) return;
    composition = Map<String, dynamic>.from(composition!)..remove('preview');
  }

  void movePhoto(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final p = photos.removeAt(oldIndex);
    photos.insert(newIndex, p);
    changed();
  }
}