import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/in_app_notification.dart';

const _supportEmail = 'support@comiverse.com';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = <({String question, String answer})>[
      (
        question: context.tr('How do I save comics and sync my progress?'),
        answer: context.tr(
          'Sign in, then use Save or Favorite on a comic. Your library and reading progress will be synced with your account.',
        ),
      ),
      (
        question: context.tr('How can I change the app language or theme?'),
        answer: context.tr(
          'Open Profile, then choose Language or Theme under App Settings. Changes are applied immediately and kept for future sessions.',
        ),
      ),
      (
        question: context.tr('Why can I not connect to the server?'),
        answer: context.tr(
          'Check your internet connection and try again. When developing locally, make sure Spring Boot is running and the API base URL is correct for your device.',
        ),
      ),
      (
        question: context.tr('How do notification preferences work?'),
        answer: context.tr(
          'Open Profile and select Notification Preferences. You can enable or disable each notification category available for your account role.',
        ),
      ),
      (
        question: context.tr('How do I report inappropriate content?'),
        answer: context.tr(
          'Send the comic, chapter, comment, or discussion link to our support email with a short description. The moderation team will review it.',
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Help Center'))),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _PageWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DocumentHeader(
                    icon: Icons.support_agent_rounded,
                    title: context.tr('How can we help?'),
                    subtitle: context.tr(
                      'Find quick answers or contact the ComiVerse support team.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.tr('Frequently Asked Questions'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  for (final faq in faqs) ...[
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        title: Text(
                          faq.question,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              faq.answer,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 14),
                  _SupportCard(
                    title: context.tr('Still need help?'),
                    message: context.tr(
                      'Email us and include your account email, device, and a short description of the issue. We usually respond within 24 hours on business days.',
                    ),
                    buttonLabel: context.tr('Copy support email'),
                    onPressed: () => _copySupportEmail(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalDocumentScreen(
      title: context.tr('Privacy Policy'),
      icon: Icons.shield_outlined,
      introduction: context.tr(
        'This policy explains what information ComiVerse collects, why we use it, and the choices available to you.',
      ),
      sections: [
        _LegalSection(
          icon: Icons.inventory_2_outlined,
          title: context.tr('1. Information We Collect'),
          body: context.tr(
            'We collect account information you provide, such as your username, email, display name, profile details, and authentication data. We also store activity needed for the service, including saved comics, likes, reading history, comments, notification preferences, and Premium status.',
          ),
        ),
        _LegalSection(
          icon: Icons.auto_awesome_outlined,
          title: context.tr('2. How We Use Information'),
          body: context.tr(
            'We use this information to operate your account, synchronize your library, personalize recommendations, deliver notifications, process Premium features, improve reliability, and protect ComiVerse from fraud or abuse.',
          ),
        ),
        _LegalSection(
          icon: Icons.hub_outlined,
          title: context.tr('3. Sharing and Service Providers'),
          body: context.tr(
            'We do not sell your personal information. Data may be processed by service providers that help us host, secure, monitor, or deliver ComiVerse. We may disclose information when required by law or to protect users and the platform.',
          ),
        ),
        _LegalSection(
          icon: Icons.security_rounded,
          title: context.tr('4. Storage and Security'),
          body: context.tr(
            'We use reasonable technical and organizational safeguards to protect your information. No online service can guarantee absolute security, so keep your password private and notify support if you suspect unauthorized access.',
          ),
        ),
        _LegalSection(
          icon: Icons.manage_accounts_outlined,
          title: context.tr('5. Your Choices and Rights'),
          body: context.tr(
            'You can update profile details and notification preferences in the app. You may also request access to, correction of, or deletion of your personal information by contacting support, subject to legal and operational retention requirements.',
          ),
        ),
      ],
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalDocumentScreen(
      title: context.tr('Terms of Service'),
      icon: Icons.balance_rounded,
      introduction: context.tr(
        'Please read these terms before accessing or using ComiVerse.',
      ),
      sections: [
        _LegalSection(
          icon: Icons.description_outlined,
          title: context.tr('1. Acceptance of Terms'),
          body: context.tr(
            'By accessing or using ComiVerse, you agree to these Terms of Service and our Privacy Policy. If you do not agree, do not use the service. These terms apply to visitors, registered users, and content contributors.',
          ),
        ),
        _LegalSection(
          icon: Icons.manage_accounts_outlined,
          title: context.tr('2. User Accounts'),
          body: context.tr(
            'You must provide accurate account information and safeguard your credentials. You are responsible for activity under your account and should notify us immediately of unauthorized use. We may suspend or terminate accounts that violate these terms.',
          ),
        ),
        _LegalSection(
          icon: Icons.verified_user_outlined,
          title: context.tr('3. Content Guidelines'),
          body: context.tr(
            'You retain ownership of original content you submit. By publishing it, you grant ComiVerse a non-exclusive license to display, distribute, and promote it through the service. Content must not violate intellectual property rights or contain illegal, harmful, offensive, or misleading material.',
          ),
        ),
        _LegalSection(
          icon: Icons.warning_amber_rounded,
          title: context.tr('4. Prohibited Activities'),
          body: context.tr(
            'You may not access another account without permission, scrape data, upload malicious code, impersonate others, bypass security controls, manipulate service metrics, or disrupt normal platform operation. Violations may lead to content removal or account termination.',
          ),
        ),
        _LegalSection(
          icon: Icons.balance_outlined,
          title: context.tr('5. Limitation of Liability'),
          body: context.tr(
            'To the extent permitted by law, ComiVerse is not liable for indirect, incidental, special, consequential, or punitive damages resulting from your use of the service. Our total liability will not exceed the amount you paid to ComiVerse in the previous twelve months.',
          ),
        ),
      ],
    );
  }
}

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({
    required this.title,
    required this.icon,
    required this.introduction,
    required this.sections,
  });

  final String title;
  final IconData icon;
  final String introduction;
  final List<_LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _PageWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DocumentHeader(
                    icon: icon,
                    title: title,
                    subtitle: context.tr('Last updated: July 2026'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    introduction,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final section in sections) ...[
                    _LegalSectionCard(section: section),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  _SupportCard(
                    title: context.tr('Questions about this document?'),
                    message: context.tr(
                      'Contact the ComiVerse support team at {email}.',
                      values: {'email': _supportEmail},
                    ),
                    buttonLabel: context.tr('Copy support email'),
                    onPressed: () => _copySupportEmail(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageWidth extends StatelessWidget {
  const _PageWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: child,
      ),
    );
  }
}

class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primaryContainer,
                context.cvColors.brandPink.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, size: 30, color: scheme.primary),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _LegalSection {
  const _LegalSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _LegalSectionCard extends StatelessWidget {
  const _LegalSectionCard({required this.section});

  final _LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  section.icon,
                  size: 22,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              section.body,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.2),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mail_outline_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(message),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.copy_rounded),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _copySupportEmail(BuildContext context) async {
  await Clipboard.setData(const ClipboardData(text: _supportEmail));
  if (!context.mounted) return;
  InAppNotifications.success(
    context,
    title: context.tr('Success'),
    message: context.tr('Support email copied.'),
  );
}
