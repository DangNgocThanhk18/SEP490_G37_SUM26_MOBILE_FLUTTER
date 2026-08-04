import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/chapter.dart';
import '../models/offline_download.dart';
import '../services/api_client.dart';
import '../services/offline_download_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/in_app_notification.dart';
import 'reader_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({
    super.key,
    required this.apiClient,
    required this.offlineDownloads,
  });

  final ApiClient apiClient;
  final OfflineDownloadService offlineDownloads;

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late Future<List<OfflineDownloadEntry>> _future = _load();
  final Set<String> _busy = {};

  Future<List<OfflineDownloadEntry>> _load() =>
      widget.offlineDownloads.listDownloads();

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _open(OfflineDownloadEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderScreen(
          apiClient: widget.apiClient,
          offlineDownloads: widget.offlineDownloads,
          preferOffline: true,
          chapters: [
            ChapterLite(
              id: entry.chapterId,
              comicId: entry.comicId,
              chapterNumber: entry.chapterNumber,
              title: entry.chapterTitle,
              isPremium: true,
            ),
          ],
          initialIndex: 0,
          comicTitle: entry.comicTitle,
        ),
      ),
    );
  }

  Future<void> _renew(OfflineDownloadEntry entry) async {
    if (_busy.contains(entry.chapterId)) return;
    setState(() => _busy.add(entry.chapterId));
    try {
      await widget.offlineDownloads.renewChapter(entry.chapterId);
      if (!mounted) return;
      InAppNotifications.success(
        context,
        title: context.tr('Offline access renewed'),
        message: context.tr(
          'This chapter can be read offline for up to 7 more days.',
        ),
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      InAppNotifications.error(
        context,
        title: context.tr('Renewal failed'),
        message: context.localizedError(error),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(entry.chapterId));
    }
  }

  Future<void> _delete(OfflineDownloadEntry entry) async {
    final confirmed = await InAppModal.confirm(
      context,
      title: context.tr('Remove download?'),
      message: context.tr(
        'Remove Chapter {number} from this device?',
        values: {'number': entry.chapterNumber},
      ),
      confirmLabel: context.tr('Remove'),
      cancelLabel: context.tr('Cancel'),
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;
    await widget.offlineDownloads.deleteDownload(entry.chapterId);
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Downloads')),
        actions: [
          IconButton(
            tooltip: context.tr('Manage offline devices'),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _OfflineDevicesScreen(
                    offlineDownloads: widget.offlineDownloads,
                  ),
                ),
              );
              if (mounted) await _reload();
            },
            icon: const Icon(Icons.devices_rounded),
          ),
          IconButton(
            tooltip: context.tr('Refresh'),
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<OfflineDownloadEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ApiErrorState(error: snapshot.error!, onRetry: _reload);
          }
          final entries = snapshot.data ?? const [];
          if (entries.isEmpty) {
            return EmptyState(
              icon: Icons.download_done_rounded,
              message: context.tr('No chapters are downloaded on this device.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_user_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr(
                            'Downloaded chapters stay encrypted. Connect to the Internet at least once every 7 days to verify Premium access.',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              for (final entry in entries)
                Card(
                  child: ListTile(
                    minTileHeight: 84,
                    leading: const CircleAvatar(
                      child: Icon(Icons.offline_pin_rounded),
                    ),
                    title: Text(
                      entry.comicTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${context.tr('Chapter {number}', values: {'number': entry.chapterNumber})}\n'
                      '${context.tr('Offline until {date}', values: {'date': _date(entry.offlineUntil)})} · ${_size(entry.sizeBytes)}',
                    ),
                    isThreeLine: true,
                    onTap: () => _open(entry),
                    trailing: PopupMenuButton<String>(
                      enabled: !_busy.contains(entry.chapterId),
                      onSelected: (value) {
                        if (value == 'renew') _renew(entry);
                        if (value == 'delete') _delete(entry);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'renew',
                          child: Text(context.tr('Renew offline access')),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(context.tr('Remove download')),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  static String _size(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
  }
}

class _OfflineDevicesScreen extends StatefulWidget {
  const _OfflineDevicesScreen({required this.offlineDownloads});

  final OfflineDownloadService offlineDownloads;

  @override
  State<_OfflineDevicesScreen> createState() => _OfflineDevicesScreenState();
}

class _OfflineDevicesScreenState extends State<_OfflineDevicesScreen> {
  late Future<(List<OfflineRegisteredDevice>, String?)> _future = _load();
  final Set<String> _busy = {};

  Future<(List<OfflineRegisteredDevice>, String?)> _load() async => (
    await widget.offlineDownloads.listRegisteredDevices(),
    await widget.offlineDownloads.currentDeviceKeyId(),
  );

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _revoke(OfflineRegisteredDevice device, bool isCurrent) async {
    final confirmed = await InAppModal.confirm(
      context,
      title: context.tr('Revoke offline device?'),
      message: context.tr(
        isCurrent
            ? 'This is the current device. Revoking it removes all local downloads and requires device enrollment again.'
            : 'This device will no longer be able to renew or open its downloaded chapters.',
      ),
      confirmLabel: context.tr('Revoke'),
      cancelLabel: context.tr('Cancel'),
      destructive: true,
      icon: Icons.phonelink_erase_rounded,
    );
    if (!confirmed) return;
    setState(() => _busy.add(device.deviceKeyId));
    try {
      await widget.offlineDownloads.revokeDevice(device.deviceKeyId);
      if (!mounted) return;
      InAppNotifications.success(
        context,
        title: context.tr('Device revoked'),
        message: context.tr('Offline access was removed from that device.'),
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      InAppNotifications.error(
        context,
        title: context.tr('Could not revoke device'),
        message: context.localizedError(error),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(device.deviceKeyId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Offline devices'))),
      body: FutureBuilder<(List<OfflineRegisteredDevice>, String?)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ApiErrorState(error: snapshot.error!, onRetry: _reload);
          }
          final devices = snapshot.data?.$1 ?? const [];
          final currentId = snapshot.data?.$2;
          if (devices.isEmpty) {
            return EmptyState(
              icon: Icons.devices_other_rounded,
              message: context.tr('No offline devices are registered.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              final current = device.deviceKeyId == currentId;
              final busy = _busy.contains(device.deviceKeyId);
              return Card(
                child: ListTile(
                  minTileHeight: 80,
                  leading: Icon(
                    current ? Icons.smartphone_rounded : Icons.devices_rounded,
                  ),
                  title: Text(device.deviceName),
                  subtitle: Text(
                    [
                      if (current) context.tr('Current device'),
                      if (device.lastSeenAt != null)
                        context.tr(
                          'Last verified {date}',
                          values: {
                            'date': _DownloadsScreenState._date(
                              device.lastSeenAt!,
                            ),
                          },
                        ),
                    ].join(' · '),
                  ),
                  trailing: busy
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          tooltip: context.tr('Revoke'),
                          onPressed: device.revoked
                              ? null
                              : () => _revoke(device, current),
                          icon: const Icon(Icons.delete_forever_outlined),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
