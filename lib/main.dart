import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // <-- ДОБАВЛЕНО

part 'data/storage.dart';
part 'data/models.dart';
part 'data/catalog_api.dart';
part 'data/print_quality.dart';
part 'data/assistant_commands.dart';
part 'data/notifications_service.dart'; // <-- Уже есть
part 'data/validation.dart';
part 'data/composition.dart';
part 'state/store.dart';
part 'ui/common.dart';
part 'screens/auth.dart';
part 'screens/catalog.dart';
part 'screens/editor.dart';
part 'screens/ai_editor.dart';
part 'screens/book_spreads.dart';
part 'screens/chat_ui.dart';
part 'screens/photo_composer.dart';
part 'screens/checkout.dart';
part 'screens/profile.dart';
part 'screens/account_features.dart';
part 'screens/quick_order.dart';
part 'screens/admin.dart';
part 'screens/support_staff.dart';
part 'screens/staff_security.dart';
part 'screens/moderation.dart';

const bg = Color(0xfffcfaf8);
const ink = Color(0xff2b3a36);
const secondary = Color(0xff8b9291);
const red = Color(0xffe56b6b);
const border = Color(0xffebe5e1);
const peach = Color(0xfffcf1eb);
const pink = Color(0xfffdeef0);
const mint = Color(0xffe2f1ec);
const blue = Color(0xffe6f0f7);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://yrrpmqazagoctactceqk.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlycnBtcWF6YWdvY3RhY3RjZXFrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ0Nzk1NzUsImV4cCI6MjExMDA1NTU3NX0.LPt8ya2InjKNL3ykxn3LYGA5NL1noW0zJjiawm8rh1c',
  );

  await NotificationService.init();

  await loadCatalog();
  final store = Store(AndroidStorage());
  await store.load();
  runApp(PicPacApp(store: store));
}

class PicPacApp extends StatelessWidget {
  final Store store;
  const PicPacApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'picPac',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: bg,
          splashFactory: InkSparkle.splashFactory,
          colorScheme: ColorScheme.fromSeed(
            seedColor: red,
            primary: red,
            surface: Colors.white,
            surfaceContainerHighest: peach,
          ),
          fontFamily: 'Montserrat',
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: ink, fontSize: 14, height: 1.45),
            bodyLarge: TextStyle(color: ink, height: 1.45),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            foregroundColor: ink,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 18,
              color: ink,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: ink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          chipTheme: ChipThemeData(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            selectedColor: peach,
            side: const BorderSide(color: border),
            labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        home: WelcomeBookPage(store: store),
      );
}