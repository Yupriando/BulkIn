import 'package:flutter/material.dart';

import '../api.dart';
import '../offline.dart';

/// Pita kecil di atas menu bawah: status offline, jumlah perubahan yang menunggu dikirim, atau perubahan yang ditolak.
class SyncBanner extends StatefulWidget {
  const SyncBanner({super.key});

  @override
  State<SyncBanner> createState() => _SyncBannerState();
}

class _SyncBannerState extends State<SyncBanner> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    await Api.instance.sync();
    if (mounted) setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([SyncStatus.online, SyncStatus.pending, SyncStatus.rejected]),
      builder: (context, _) {
        final online = SyncStatus.online.value;
        final pending = SyncStatus.pending.value;
        final rejected = SyncStatus.rejected.value;

        final (IconData icon, String text, Color bg, Color fg)? banner = switch (()) {
          _ when rejected != null => (Icons.error_outline, rejected, scheme.errorContainer, scheme.onErrorContainer),
          _ when !online => (
              Icons.cloud_off,
              pending > 0 ? 'Offline · $pending perubahan tersimpan di HP' : 'Offline · data terakhir dari HP',
              scheme.tertiaryContainer,
              scheme.onTertiaryContainer,
            ),
          _ when pending > 0 => (
              Icons.cloud_upload_outlined,
              'Mengirim $pending perubahan…',
              scheme.primaryContainer,
              scheme.onPrimaryContainer,
            ),
          _ => null,
        };

        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: banner == null
              ? const SizedBox(width: double.infinity)
              : Material(
                  color: banner.$3,
                  child: InkWell(
                    onTap: rejected != null ? () => SyncStatus.rejected.value = null : (_syncing ? null : _syncNow),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(banner.$1, size: 18, color: banner.$4),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              banner.$2,
                              style: TextStyle(color: banner.$4, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          if (_syncing)
                            SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: banner.$4),
                            )
                          else
                            Text(
                              rejected != null ? 'Tutup' : 'Coba kirim',
                              style: TextStyle(color: banner.$4, fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
