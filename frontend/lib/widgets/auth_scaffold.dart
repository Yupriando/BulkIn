import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';

/// Kerangka layar login & daftar: header biru tua bergradasi dengan logo, lalu kartu form.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: Brand.gradientOf(context)),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (showBack)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                Expanded(
                  // SliverFillRemaining: kartu form selalu memanjang sampai bawah layar,
                  // tapi tetap bisa di-scroll saat keyboard muncul.
                  child: CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          children: [
                            SizedBox(height: showBack ? 0 : 40),
                            const NaikInBadge(size: 84),
                            const SizedBox(height: 16),
                            Text(
                              title,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: Text(
                                subtitle,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(32),
                                  ),
                                ),
                                padding: EdgeInsets.fromLTRB(
                                  24,
                                  28,
                                  24,
                                  24 + MediaQuery.paddingOf(context).bottom,
                                ),
                                child: child,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
