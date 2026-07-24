import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/premium_plan.dart';
import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/in_app_notification.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key, required this.apiClient, required this.user});

  final ApiClient apiClient;
  final UserProfile user;

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  late Future<PremiumPlanSettings> _future = widget.apiClient.getPremiumPlans();
  String _selected = 'YEARLY';
  bool _upgrading = false;

  void _reload() =>
      setState(() => _future = widget.apiClient.getPremiumPlans());

  Future<void> _upgrade() async {
    final confirmed = await InAppModal.confirm(
      context,
      title: context.tr('Confirm Premium upgrade'),
      message: context.tr(
        'Continue with the {plan} plan?',
        values: {
          'plan': context.tr(_selected == 'YEARLY' ? 'Yearly' : 'Monthly'),
        },
      ),
      confirmLabel: context.tr('Confirm'),
      cancelLabel: context.tr('Cancel'),
      icon: Icons.workspace_premium_rounded,
      barrierDismissible: false,
    );
    if (!confirmed) return;
    setState(() => _upgrading = true);
    try {
      await widget.apiClient.upgradePlan(_selected);
      if (mounted) {
        InAppNotifications.success(
          context,
          title: context.tr('Welcome to Premium'),
          message: context.tr('Your Premium plan is now active.'),
          duration: const Duration(seconds: 6),
        );
      }
    } catch (error) {
      if (mounted) {
        InAppNotifications.error(
          context,
          title: context.tr('Upgrade failed'),
          message: context.localizedError(error),
          duration: null,
        );
      }
    } finally {
      if (mounted) setState(() => _upgrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Premium Upgrade'))),
      body: FutureBuilder<PremiumPlanSettings>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ApiErrorState(error: snapshot.error!, onRetry: _reload);
          }
          final plans = snapshot.data!;
          return LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth > 720
                  ? 680.0
                  : constraints.maxWidth;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                          ),
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            size: 48,
                            color: context.cvColors.rating,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          context.tr('Read without limits'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr(
                            'Unlock the complete catalog, support creators, and enjoy a cleaner reading experience.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              children: [
                                for (final benefit in plans.benefits)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 7,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline_rounded,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(context.tr(benefit)),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Text(
                          context.tr('Choose your plan'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        _PlanOption(
                          title: context.tr('Premium Yearly'),
                          price: _formatCurrency(plans.yearlyPrice),
                          period: context.tr('/ year'),
                          badge: context.tr('BEST VALUE'),
                          selected: _selected == 'YEARLY',
                          onTap: () => setState(() => _selected = 'YEARLY'),
                        ),
                        const SizedBox(height: 10),
                        _PlanOption(
                          title: context.tr('Premium Monthly'),
                          price: _formatCurrency(plans.monthlyPrice),
                          period: context.tr('/ month'),
                          selected: _selected == 'MONTHLY',
                          onTap: () => setState(() => _selected = 'MONTHLY'),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryGradientButton(
                            label: context.tr(
                              widget.user.premiumActive
                                  ? 'Switch Premium Plan'
                                  : 'Start Premium',
                            ),
                            loading: _upgrading,
                            onPressed: _upgrade,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr(
                            'Plan availability and prices are loaded from ComiVerse system settings.',
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatCurrency(double value) {
    final whole = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write('.');
      buffer.write(whole[i]);
    }
    return '${buffer.toString()}₫';
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.title,
    required this.price,
    required this.period,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String price;
  final String period;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? scheme.primary : context.cvColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.cvColors.brandOrange,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: price,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: scheme.primary),
                          ),
                          TextSpan(text: ' $period'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? scheme.primary : scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
