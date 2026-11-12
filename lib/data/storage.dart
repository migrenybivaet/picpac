part of '../main.dart';

abstract class AppStorage {
  Future<String?> load();
  Future<String?> photoDirectory();
  Future<String?> authState();
  Future<String?> legacyOwner();
  Future<String?> adminState();
  Future<String?> supportState();
  Future<String> setupStaff(String role, String password);
  Future<String> staffAccessState(String role);
  Future<bool> verifyDeviceOwner();
  Future<String> authenticateSupport(String email, String password);
  Future<void> supportLogout();
  Future<bool> adminExists();
  Future<String> authenticateAdmin(
    String email,
    String password, {
    required bool setup,
  });
  Future<void> adminLogout();
  Future<List<Map<String, dynamic>>> adminListUsers();
  Future<void> adminSetDisabled(String email, bool disabled);
  Future<String> authenticate(
    String email,
    String password, {
    required bool register,
  });
  Future<void> logout();
  Future<void> deleteAccount();
  Future<void> save(String value);
  Future<PickResult> pick();
  Future<Photo> segmentPortrait(String sourceId,
      {String? backgroundId, int? color});
  Future<void> delete(String id);
}

class AndroidStorage implements AppStorage {
  static const channel = MethodChannel('by.picpac.demo/storage');
  
  @override
  Future<String?> load() => channel.invokeMethod<String>('loadState');
  @override
  Future<String?> photoDirectory() =>
      channel.invokeMethod<String>('photoDirectory');
  @override
  Future<String?> authState() => channel.invokeMethod<String>('authState');
  @override
  Future<String?> legacyOwner() => channel.invokeMethod<String>('legacyOwner');
  @override
  Future<String?> adminState() => channel.invokeMethod<String>('adminState');
  @override
  Future<String?> supportState() =>
      channel.invokeMethod<String>('supportState');
      
  @override
  Future<String> authenticateSupport(String email, String password) async =>
      (await channel.invokeMethod<String>('supportLogin', {
        'email': email,
        'password': password,
      }))!;
      
  @override
  Future<void> supportLogout() => channel.invokeMethod<void>('supportLogout');
  
  @override
  Future<String> setupStaff(String role, String password) async =>
      (await channel.invokeMethod<String>('setupStaff', {
        'role': role,
        'password': password,
      }))!;
      
  @override
  Future<String> staffAccessState(String role) async =>
      (await channel
          .invokeMethod<String>('staffAccessState', {'role': role})) ??
      'unknown';
      
  @override
  Future<bool> verifyDeviceOwner() async =>
      await channel.invokeMethod<bool>('verifyDeviceOwner') ?? false;
      
  @override
  Future<bool> adminExists() async =>
      await channel.invokeMethod<bool>('adminExists') ?? false;
      
  @override
  Future<String> authenticateAdmin(
    String email,
    String password, {
    required bool setup,
  }) async =>
      (await channel.invokeMethod<String>(
        setup ? 'adminSetup' : 'adminLogin',
        {'email': email, 'password': password},
      ))!;
      
  @override
  Future<void> adminLogout() => channel.invokeMethod<void>('adminLogout');
  
  @override
  Future<List<Map<String, dynamic>>> adminListUsers() async =>
      ((await channel.invokeListMethod<dynamic>('adminListUsers')) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
          
  @override
  Future<void> adminSetDisabled(String email, bool disabled) =>
      channel.invokeMethod<void>('adminSetDisabled', {
        'email': email,
        'disabled': disabled,
      });
      
  @override
  Future<String> authenticate(
    String email,
    String password, {
    required bool register,
  }) async =>
      (await channel.invokeMethod<String>(
        register ? 'authRegister' : 'authLogin',
        {'email': email, 'password': password},
      ))!;
      
  @override
  Future<void> logout() => channel.invokeMethod<void>('authLogout');
  
  @override
  Future<void> deleteAccount() => channel.invokeMethod<void>('authDelete');
  
  @override
  Future<void> save(String value) =>
      channel.invokeMethod<void>('saveState', {'data': value});
      
  @override
  Future<void> delete(String id) =>
      channel.invokeMethod<void>('deletePhoto', {'id': id});
      
  @override
  Future<Photo> segmentPortrait(String sourceId,
      {String? backgroundId, int? color}) async {
    final raw =
        await channel.invokeMapMethod<String, dynamic>('segmentPortrait', {
      'sourceId': sourceId,
      'backgroundId': backgroundId,
      'color': color,
    });
    if (raw == null) throw StateError('Пустой результат обработки');
    return Photo.fromMap(Map<String, dynamic>.from(raw));
  }

  @override
  Future<PickResult> pick() async {
    final raw = await channel.invokeMapMethod<String, dynamic>('pickPhotos');
    final files = (raw?['photos'] as List? ?? [])
        .map((e) => Photo.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final errors =
        (raw?['errors'] as List? ?? []).map((e) => e.toString()).toList();
    return PickResult(files, errors);
  }
}