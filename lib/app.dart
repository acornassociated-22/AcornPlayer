import 'package:flutter/material.dart';

import 'screens/library_screen.dart';
import 'theme/app_colors.dart';
import 'widgets/app_shell.dart';

class AcornApp extends StatelessWidget {
  const AcornApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Acorn Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        canvasColor: AppColors.background,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      // Wrapping the navigator keeps the caption bar above every route.
      builder: (context, child) => AppShell(child: child ?? const SizedBox()),
      home: const LibraryScreen(),
    );
  }
}
