import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
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
  });

  final ApiClient apiClient;
  final UserProfile? user;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenHistory;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: EmptyState(
          icon: Icons.person_outline_rounded,
          message: 'Sign in to manage your profile and Premium plan.',
          actionLabel: 'Sign in',
          onAction: onSignOut,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
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
                              : 'Upgrade to ComiVerse Premium',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  if (user!.premiumExpiresAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Active until ${_formatDate(user!.premiumExpiresAt!)}',
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryGradientButton(
                      label: user!.premiumActive
                          ? 'Manage Plan'
                          : 'View Premium Plans',
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
            title: 'Account',
            children: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                title: 'Personal Information',
                subtitle: user!.email,
                onTap: () => _showProfileInfo(context),
              ),
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Change Password',
                onTap: () => _showChangePassword(context),
              ),
              _SettingsTile(
                icon: Icons.history_rounded,
                title: 'Reading History',
                onTap: onOpenHistory,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsGroup(
            title: 'App Settings',
            children: [
              _SettingsTile(
                icon: isDarkMode
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                title: 'Theme',
                value: isDarkMode ? 'Dark' : 'Light',
                onTap: onToggleTheme,
              ),
              const _SettingsTile(
                icon: Icons.language_rounded,
                title: 'Language',
                value: 'English',
              ),
              const _SettingsTile(
                icon: Icons.notifications_active_outlined,
                title: 'Notification Preferences',
              ),
              const _SettingsTile(
                icon: Icons.download_outlined,
                title: 'Downloads',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SettingsGroup(
            title: 'Support & Privacy',
            children: [
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                title: 'Help Center',
              ),
              _SettingsTile(
                icon: Icons.shield_outlined,
                title: 'Privacy Policy',
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
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
            label: const Text('Sign Out'),
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
                'Personal Information',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Display name'),
                subtitle: Text(user!.displayName),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alternate_email_rounded),
                title: const Text('Username'),
                subtitle: Text(user!.username),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(user!.email),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    var loading = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (next.text.length < 6) {
                        setModalState(
                          () => error =
                              'New password must have at least 6 characters.',
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
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password updated.')),
                          );
                        }
                      } catch (exception) {
                        setModalState(() {
                          loading = false;
                          error = exception.toString();
                        });
                      }
                    },
              child: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
    current.dispose();
    next.dispose();
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your current session will be closed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) onSignOut();
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
