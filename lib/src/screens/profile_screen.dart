import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/notification_preferences.dart';
import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/profile_image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/in_app_notification.dart';
import 'premium_screen.dart';
import 'support_legal_screens.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.apiClient,
    required this.user,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onOpenHistory,
    required this.onSignOut,
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
    this.locale = const Locale('en'),
    this.onLocaleChanged,
    this.onUserChanged,
    this.imagePicker = const DeviceProfileImagePicker(),
  });

  final ApiClient apiClient;
  final UserProfile? user;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onOpenHistory;
  final VoidCallback onSignOut;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final Locale locale;
  final ValueChanged<Locale>? onLocaleChanged;
  final ValueChanged<UserProfile>? onUserChanged;
  final ProfileImagePicker imagePicker;

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
          _ProfileIdentityHeader(user: user!),
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
                onTap: () => _showEditProfile(context),
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
                value: context.tr(switch (themeMode) {
                  ThemeMode.system => 'System',
                  ThemeMode.light => 'Light',
                  ThemeMode.dark => 'Dark',
                }),
                onTap: onThemeModeChanged == null
                    ? onToggleTheme
                    : () => _showThemePicker(context),
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
                onTap: () => _showNotificationPreferences(context),
              ),
              _SettingsTile(
                icon: Icons.download_outlined,
                title: context.tr('Downloads'),
                value: context.tr('Coming soon'),
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
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.shield_outlined,
                title: context.tr('Privacy Policy'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: context.tr('Terms of Service'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TermsOfServiceScreen(),
                  ),
                ),
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

  Future<void> _showEditProfile(BuildContext context) async {
    final updated = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _EditProfileSheet(
        apiClient: apiClient,
        user: user!,
        imagePicker: imagePicker,
      ),
    );
    if (updated == null || !context.mounted) return;
    onUserChanged?.call(updated);
    InAppNotifications.success(
      context,
      title: context.tr('Success'),
      message: context.tr('Profile updated.'),
    );
  }

  Future<void> _showThemePicker(BuildContext context) async {
    final selected = await showModalBottomSheet<ThemeMode>(
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
                sheetContext.tr('Select theme'),
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              for (final option in ThemeMode.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      minTileHeight: 60,
                      leading: Icon(switch (option) {
                        ThemeMode.system => Icons.brightness_auto_rounded,
                        ThemeMode.light => Icons.light_mode_rounded,
                        ThemeMode.dark => Icons.dark_mode_rounded,
                      }),
                      title: Text(
                        sheetContext.tr(switch (option) {
                          ThemeMode.system => 'System default',
                          ThemeMode.light => 'Light',
                          ThemeMode.dark => 'Dark',
                        }),
                      ),
                      trailing: Icon(
                        option == themeMode
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: option == themeMode
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
    if (selected != null) onThemeModeChanged?.call(selected);
  }

  Future<void> _showNotificationPreferences(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NotificationPreferencesSheet(apiClient: apiClient),
    );
    if (saved == true && context.mounted) {
      InAppNotifications.success(
        context,
        title: context.tr('Success'),
        message: context.tr('Notification preferences saved.'),
      );
    }
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

class _ProfileIdentityHeader extends StatelessWidget {
  const _ProfileIdentityHeader({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final backgroundUrl = user.backgroundImageUrl?.trim();
    final avatarUrl = user.avatarUrl?.trim();
    final displayName = user.displayName.trim();
    final fallbackName = displayName.isNotEmpty
        ? displayName
        : user.username.trim();
    final initial = fallbackName.isEmpty
        ? '?'
        : fallbackName.characters.first.toUpperCase();

    Widget backgroundFallback() => DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            context.cvColors.brandPink.withValues(alpha: 0.32),
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: scheme.onPrimaryContainer.withValues(alpha: 0.35),
            size: 34,
          ),
        ),
      ),
    );

    Widget avatarFallback() => ColoredBox(
      color: scheme.primaryContainer,
      child: Center(
        child: Text(initial, style: Theme.of(context).textTheme.displaySmall),
      ),
    );

    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  key: const Key('profile-background-banner'),
                  width: double.infinity,
                  height: 138,
                  child: backgroundUrl?.isNotEmpty == true
                      ? Image.network(
                          backgroundUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => backgroundFallback(),
                        )
                      : backgroundFallback(),
                ),
              ),
              Positioned(
                bottom: -52,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      key: const Key('profile-avatar-image'),
                      width: 108,
                      height: 108,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.shadow.withValues(alpha: 0.22),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: avatarUrl?.isNotEmpty == true
                            ? Image.network(
                                avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => avatarFallback(),
                              )
                            : avatarFallback(),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: 4,
                      child: CircleAvatar(
                        radius: 17,
                        backgroundColor: context.cvColors.brandPink,
                        child: const Icon(Icons.star_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 66),
          Text(displayName, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 3),
          Text(
            '@${user.username}',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              user.role ?? 'READER',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.apiClient,
    required this.user,
    required this.imagePicker,
  });

  final ApiClient apiClient;
  final UserProfile user;
  final ProfileImagePicker imagePicker;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _bio;
  String? _avatarUrl;
  String? _backgroundImageUrl;
  ProfileImageSelection? _avatarSelection;
  ProfileImageSelection? _backgroundSelection;
  String? _uploadedAvatarUrl;
  String? _uploadedBackgroundUrl;
  DateTime? _dateOfBirth;
  bool _saving = false;
  bool _uploadingImages = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController(text: widget.user.displayName);
    _avatarUrl = widget.user.avatarUrl;
    _backgroundImageUrl = widget.user.backgroundImageUrl;
    _bio = TextEditingController(text: widget.user.bio ?? '');
    _dateOfBirth = widget.user.dateOfBirth;
  }

  @override
  void dispose() {
    _fullName.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (selected != null) setState(() => _dateOfBirth = selected);
  }

  Future<void> _pickImage(ProfileImageKind kind) async {
    if (_saving) return;
    setState(() => _error = null);
    try {
      final selection = await widget.imagePicker.pick(kind);
      if (selection == null || !mounted) return;
      setState(() {
        if (kind == ProfileImageKind.avatar) {
          _avatarSelection = selection;
          _uploadedAvatarUrl = null;
        } else {
          _backgroundSelection = selection;
          _uploadedBackgroundUrl = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = context.localizedError(error));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final fullName = _fullName.text.trim();
    final bio = _bio.text;
    final dateOfBirth = _dateOfBirth;
    setState(() {
      _saving = true;
      _uploadingImages =
          _avatarSelection != null || _backgroundSelection != null;
      _error = null;
    });
    try {
      var avatarUrl = _uploadedAvatarUrl ?? _avatarUrl;
      var backgroundImageUrl = _uploadedBackgroundUrl ?? _backgroundImageUrl;

      final avatarSelection = _avatarSelection;
      if (avatarSelection != null && _uploadedAvatarUrl == null) {
        avatarUrl = await widget.apiClient.uploadImage(
          bytes: avatarSelection.bytes,
          fileName: avatarSelection.fileName,
          contentType: avatarSelection.contentType,
        );
        _uploadedAvatarUrl = avatarUrl;
      }

      final backgroundSelection = _backgroundSelection;
      if (backgroundSelection != null && _uploadedBackgroundUrl == null) {
        backgroundImageUrl = await widget.apiClient.uploadImage(
          bytes: backgroundSelection.bytes,
          fileName: backgroundSelection.fileName,
          contentType: backgroundSelection.contentType,
        );
        _uploadedBackgroundUrl = backgroundImageUrl;
      }

      if (mounted) setState(() => _uploadingImages = false);
      final updated = await widget.apiClient.updateProfile(
        fullName: fullName,
        avatarUrl: avatarUrl,
        backgroundImageUrl: backgroundImageUrl,
        dateOfBirth: dateOfBirth,
        bio: bio,
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _uploadingImages = false;
        _error = context.localizedError(error);
      });
    }
  }

  Widget _avatarPreview(BuildContext context) {
    final selectedBytes = _avatarSelection?.bytes;
    final image = selectedBytes != null
        ? Image.memory(
            selectedBytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _avatarFallback(context),
          )
        : _avatarUrl?.trim().isNotEmpty == true
        ? Image.network(
            _avatarUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _avatarFallback(context),
          )
        : _avatarFallback(context);

    return Semantics(
      image: true,
      label: context.tr(
        selectedBytes == null
            ? 'Current profile photo'
            : 'Selected profile photo',
      ),
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: image,
            ),
            Positioned(
              right: -3,
              bottom: -3,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                child: const Icon(Icons.photo_camera_rounded, size: 17),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(BuildContext context) {
    final initial = _fullName.text.trim().isEmpty
        ? widget.user.username.characters.first.toUpperCase()
        : _fullName.text.trim().characters.first.toUpperCase();
    return ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
        child: Text(initial, style: Theme.of(context).textTheme.headlineSmall),
      ),
    );
  }

  Widget _backgroundPreview(BuildContext context) {
    final selectedBytes = _backgroundSelection?.bytes;
    final fallback = ColoredBox(
      color: context.cvColors.surfaceSubtle,
      child: Center(
        child: Icon(
          Icons.landscape_rounded,
          size: 40,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
    final image = selectedBytes != null
        ? Image.memory(
            selectedBytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : _backgroundImageUrl?.trim().isNotEmpty == true
        ? Image.network(
            _backgroundImageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : fallback;

    return Semantics(
      image: true,
      label: context.tr(
        selectedBytes == null
            ? 'Current profile background'
            : 'Selected profile background',
      ),
      child: ExcludeSemantics(child: image),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Edit profile'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.tr('Profile photos'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              _avatarPreview(context),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('Profile photo'),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      context.tr(
                                        'JPG, PNG, GIF or WebP up to 2MB.',
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton.filledTonal(
                                key: const Key('edit-profile-avatar-picker'),
                                tooltip: context.tr('Choose profile photo'),
                                onPressed: _saving
                                    ? null
                                    : () => _pickImage(ProfileImageKind.avatar),
                                icon: const Icon(Icons.add_a_photo_outlined),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        SizedBox(
                          width: double.infinity,
                          height: 112,
                          child: _backgroundPreview(context),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('Profile background'),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      context.tr(
                                        'JPG, PNG, GIF or WebP up to 4MB.',
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton.filledTonal(
                                key: const Key(
                                  'edit-profile-background-picker',
                                ),
                                tooltip: context.tr(
                                  'Choose profile background',
                                ),
                                onPressed: _saving
                                    ? null
                                    : () => _pickImage(
                                        ProfileImageKind.background,
                                      ),
                                icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fullName,
                    enabled: !_saving,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: context.tr('Display name'),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? context.tr('Display name is required.')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.cake_outlined),
                      title: Text(context.tr('Date of birth')),
                      subtitle: Text(
                        _dateOfBirth == null
                            ? context.tr('Not set')
                            : _dateOfBirth!.toIso8601String().split('T').first,
                      ),
                      trailing: _dateOfBirth == null
                          ? const Icon(Icons.chevron_right_rounded)
                          : IconButton(
                              tooltip: context.tr('Clear'),
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _dateOfBirth = null),
                              icon: const Icon(Icons.close_rounded),
                            ),
                      onTap: _saving ? null : _pickDate,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bio,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      labelText: context.tr('Bio'),
                      alignLabelWithHint: true,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 72),
                        child: Icon(Icons.notes_rounded),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (_saving) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      label: context.tr(
                        _uploadingImages
                            ? 'Uploading images...'
                            : 'Saving profile...',
                      ),
                      child: const LinearProgressIndicator(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                          child: Text(context.tr('Cancel')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            context.tr(
                              _uploadingImages
                                  ? 'Uploading...'
                                  : 'Save changes',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationPreferencesSheet extends StatefulWidget {
  const _NotificationPreferencesSheet({required this.apiClient});

  final ApiClient apiClient;

  @override
  State<_NotificationPreferencesSheet> createState() =>
      _NotificationPreferencesSheetState();
}

class _NotificationPreferencesSheetState
    extends State<_NotificationPreferencesSheet> {
  late Future<NotificationPreferences> _future = _load();
  Map<String, bool> _values = {};
  bool _loaded = false;
  bool _saving = false;
  String? _saveError;

  Future<NotificationPreferences> _load() async {
    final preferences = await widget.apiClient.getNotificationPreferences();
    final values = Map<String, bool>.from(preferences.values);
    if (mounted) {
      setState(() {
        _values = values;
        _loaded = true;
      });
    } else {
      _values = values;
      _loaded = true;
    }
    return preferences;
  }

  void _retry() {
    setState(() {
      _saveError = null;
      _loaded = false;
      _future = _load();
    });
  }

  Future<void> _save() async {
    if (_saving || !_loaded) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.apiClient.updateNotificationPreferences(_values);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = context.localizedError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Notification Preferences'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('Choose which in-app notifications you receive.'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<NotificationPreferences>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return ApiErrorState(
                        error: snapshot.error!,
                        onRetry: _retry,
                      );
                    }
                    final keys = snapshot.data?.availableKeys ?? const [];
                    if (keys.isEmpty) {
                      return EmptyState(
                        icon: Icons.notifications_off_outlined,
                        message: context.tr(
                          'No notification preferences are available.',
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: keys.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final key = keys[index];
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(_notificationIcon(key)),
                          title: Text(_notificationLabel(context, key)),
                          value: _values[key] ?? true,
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _values[key] = value),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_saveError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving || !_loaded ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(context.tr('Save preferences')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _notificationLabel(BuildContext context, String key) {
    return context.tr(switch (key) {
      'SYSTEM_BROADCASTS' => 'System announcements',
      'FORUM_ACTIVITY' => 'Forum activity',
      'REVIEW_QUEUE' => 'Review queue',
      'SUBMISSION_STATUS' => 'Submission status',
      'PROJECT_OPPORTUNITIES' => 'Project opportunities',
      'TEAM_UPDATES' => 'Team updates',
      'TEAM_JOIN_REQUESTS' => 'Team join requests',
      _ => key.replaceAll('_', ' '),
    });
  }

  IconData _notificationIcon(String key) {
    return switch (key) {
      'SYSTEM_BROADCASTS' => Icons.campaign_outlined,
      'FORUM_ACTIVITY' => Icons.forum_outlined,
      'REVIEW_QUEUE' => Icons.rate_review_outlined,
      'SUBMISSION_STATUS' => Icons.fact_check_outlined,
      'PROJECT_OPPORTUNITIES' => Icons.work_outline_rounded,
      'TEAM_UPDATES' => Icons.groups_outlined,
      'TEAM_JOIN_REQUESTS' => Icons.group_add_outlined,
      _ => Icons.notifications_outlined,
    };
  }
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
          if (value != null)
            Text(
              value!,
              style: TextStyle(
                color: onTap == null
                    ? Theme.of(context).colorScheme.outline
                    : null,
              ),
            ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
