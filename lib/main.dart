import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import 'providers/stress_map_controller.dart';
import 'screens/stress_map_screen.dart';
import 'widgets/admob_bottom_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await MobileAds.instance.initialize();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
        Locale('pt'),
        Locale('fr'),
        Locale('ru'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StressMapController()..load(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'app.title'.tr(),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF070A0F),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF35D07F),
            brightness: Brightness.dark,
            surface: const Color(0xFF101722),
          ),
          fontFamily: 'Roboto',
          cardTheme: CardThemeData(
            color: const Color(0xE6111824),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0x1FFFFFFF)),
            ),
          ),
        ),
        builder: (context, child) {
          return Scaffold(
            body: Column(
              children: [
                Expanded(child: child ?? const SizedBox.shrink()),
                const AdMobBottomBanner(),
              ],
            ),
          );
        },
        home: const StressMapScreen(),
      ),
    );
  }
}
