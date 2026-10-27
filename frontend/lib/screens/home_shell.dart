import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../food_store.dart';
import '../offline.dart';
import '../widgets/sync_banner.dart';
import 'foods_screen.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Simpan daftar makanan & profil di HP sejak awal, supaya bisa mencatat walau nanti offline.
    FoodStore.load().ignore();
    Api.instance.getProfile().ignore();
    // Coba kirim antrean offline secara berkala selama masih ada yang tertunda.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (SyncStatus.pending.value > 0) Api.instance.sync();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Api.instance.sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Dibuat ulang saat tab dibuka supaya datanya selalu segar.
  Widget _page() => switch (_index) {
        0 => const TodayScreen(),
        1 => const ProgressScreen(),
        2 => const FoodsScreen(),
        _ => const ProfileScreen(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _page(),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SyncBanner(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'Harian'),
              NavigationDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart), label: 'Progres'),
              NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Makanan'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
            ],
          ),
        ],
      ),
    );
  }
}
