import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/in_app_notification.dart';
import 'premium_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.apiClient,
    required this.user,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onOpenHistory,
    required this.onSignOut,
    this.locale = const Locale('en'),
    this.onLocaleChanged,
  });

  final ApiClient apiClient;
  final UserProfile? user;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenHistory;
  final VoidCallback onSignOut;
  final Locale locale;
  final ValueChanged<Locale>? onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('Profile'))),
        body: EmptyState(
          icon: Icons.person_outline_rounded,
          message: context.tr(
            'Sign in to manage your profile and Premium plan.',
          ),
          actionLabel: context.tr('Sign in'),
          onAction: onSignOut,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Profile'))),
      body: ListView(
        key: const PageStorageKey('profile-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: scheme.primaryContainer,
                      backgroundImage:
                          user!.avatarUrl?.trim().isNotEmpty == true
                          ? NetworkImage(user!.avatarUrl!)
                          : null,
                      child: user!.avatarUrl?.trim().isNotEmpty == true
                          ? null
                          : Text(
                              user!.displayName[0].toUpperCase(),
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: 2,
                      child: CircleAvatar(
                        radius: 17,
                        backgroundColor: context.cvColors.brandPink,
                        child: const Icon(Icons.star_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  user!.displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  '@${user!.username}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    user!.role ?? 'READER',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Card(
            color: scheme.primaryContainer.withValues(alpha: 0.14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        color: context.cvColors.rating,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          user!.premiumActive
                              ? 'ComiVerse ${user!.premiumPlan ?? 'Premium'}'
                              : context.tr('Upgrade to ComiVerse Premium'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  if (user!.premiumExpiresAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                        'Active until {date}',
                        values: {'date': _formatDate(user!.premiumExpiresAt!)},
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryGradientButton(
                      label: context.tr(
                        user!.premiumActive
                            ? 'Manage Plan'
                            : 'View Premium Plans',
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PremiumScreen(apiClient: apiClient, user: user!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SettingsGroup(
            title: context.tr('Account'),
            children: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                title: context.tr('Personal Information'),
                subtitle: user!.email,
                onTap: () => _showProfileInfo(context),
              ),
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: context.tr('Change Password'),
                onTap: () => _showChangePassword(context),
              ),
              _SettingsTile(
                icon: Icons.history_rounded,
                title: context.tr('Reading History'),
                onTap: onOpenHistory,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsGroup(
            title: context.tr('App Settings'),
            children: [
              _SettingsTile(
                icon: isDarkMode
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                title: context.tr('Theme'),
                value: context.tr(isDarkMode ? 'Dark' : 'Light'),
                onTap: onToggleTheme,
              ),
              _SettingsTile(
                icon: Icons.language_rounded,
                title: context.tr('Language'),
                value: context.tr(
                  locale.languageCode == 'vi' ? 'Vietnamese' : 'English',
                ),
                onTap: onLocaleChanged == null
                    ? null
                    : () => _showLanguagePicker(context),
              ),
              _SettingsTile(
                icon: Icons.notifications_active_outlined,
                title: context.tr('Notification Preferences'),
              ),
              _SettingsTile(
                icon: Icons.download_outlined,
                title: context.tr('Downloads'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsGroup(
            title: context.tr('Support & Privacy'),
            children: [
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                title: context.tr('Help Center'),
              ),
              _SettingsTile(
                icon: Icons.shield_outlined,
                title: context.tr('Privacy Policy'),
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: context.tr('Terms of Service'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: Text(context.tr('Sign Out')),
          ),
        ],
      ),
    );
  }

  void _showProfileInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Personal Information'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: Text(context.tr('Display name')),
                subtitle: Text(user!.displayName),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alternate_email_rounded),
                title: Text(context.tr('Username')),
                subtitle: Text(user!.username),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined),
                title: Text(context.tr('Email')),
                subtitle: Text(user!.email),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguagePicker(BuildContext context) async {
    final selected = await showModalBottomSheet<Locale>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheetContext.tr('Select language'),
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              for (final option in const [Locale('en'), Locale('vi')])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      minTileHeight: 60,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: Text(
                        option.languageCode == 'vi' ? '🇻🇳' : '🇬🇧',
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        sheetContext.tr(
                          option.languageCode == 'vi'
                              ? 'Vietnamese'
                              : 'English',
                        ),
                      ),
                      trailing: Icon(
                        option.languageCode == locale.languageCode
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: option.languageCode == locale.languageCode
                            ? Theme.of(sheetContext).colorScheme.primary
                            : Theme.of(sheetContext).colorScheme.outline,
                      ),
                      onTap: () => Navigator.pop(sheetContext, option),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected.languageCode != locale.languageCode) {
      onLocaleChanged?.call(selected);
      final selectedStrings = AppLocalizations(selected);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        InAppNotifications.information(
          context,
          title: selectedStrings.tr('Information'),
          message: selectedStrings.tr(
            selected.languageCode == 'vi'
                ? 'Language changed to Vietnamese.'
                : 'Language changed to English.',
          ),
        );
      });
    }
  }

  Future<void> _showChangePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    var loading = false;
    String? error;
    await InAppModal.show<void>(
      context,
      barrierDismissible: false,
      builder: (modalContext) => StatefulBuilder(
        builder: (panelContext, setModalState) => InAppModalPanel(
          title: panelContext.tr('Change Password'),
          icon: Icons.lock_reset_rounded,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: panelContext.tr('Current password'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: next,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: panelContext.tr('New password'),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: TextStyle(
                    color: Theme.of(panelContext).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(modalContext),
              child: Text(panelContext.tr('Cancel')),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (next.text.length < 6) {
                        setModalState(
                          () => error = panelContext.tr(
                            'New password must have at least 6 characters.',
                          ),
                        );
                        return;
                      }
                      setModalState(() {
                        loading = true;
                        error = null;
                      });
                      try {
                        await apiClient.changePassword(
                          currentPassword: current.text,
                          newPassword: next.text,
                        );
                        if (modalContext.mounted) Navigator.pop(modalContext);
                        if (context.mounted) {
                          InAppNotifications.success(
                            context,
                            title: context.tr('Success'),
                            message: context.tr('Password updated.'),
                          );
                        }
                      } catch (exception) {
                        setModalState(() {
                          loading = false;
                          error = panelContext.localizedError(exception);
                        });
                      }
                    },
              child: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(panelContext.tr('Update')),
            ),
          ],
        ),
      ),
    );
    current.dispose();
    next.dispose();
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await InAppModal.confirm(
      context,
      title: context.tr('Sign out?'),
      message: context.tr('Your current session will be closed.'),
      cancelLabel: context.tr('Cancel'),
      confirmLabel: context.tr('Sign Out'),
      destructive: true,
      icon: Icons.logout_rounded,
      barrierDismissible: false,
    );
    if (confirmed) onSignOut();
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 64,
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) Text(value!),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
      onTap: onTap,
    );
  }
}
