import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/page/iap_page.dart';
import 'package:anx_reader/page/settings_page/more_settings_page.dart';
import 'package:anx_reader/providers/auth.dart';
import 'package:anx_reader/providers/iap.dart';
import 'package:anx_reader/service/iap/iap_service.dart';
import 'package:anx_reader/utils/env_var.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/settings/about.dart';
import 'package:anx_reader/widgets/settings/theme_mode.dart';
import 'package:anx_reader/widgets/settings/webdav_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.controller});

  final ScrollController? controller;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final ScrollController _scrollController =
      widget.controller ?? ScrollController();

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context).authLogoutConfirmTitle),
        content: Text(L10n.of(context).authLogoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(L10n.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(L10n.of(context).authLogout),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    AnxToast.show(L10n.of(context).authLogoutSuccess);
  }

  @override
  Widget build(BuildContext context) {
    final email = Prefs().authEmail;
    final isLoggingOut = ref.watch(authProvider).isLoading;

    return Scaffold(
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 60, 0, 20),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Text(
                        'Anx',
                        style: TextStyle(
                          fontSize: 130,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(),
              if (email != null && email.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(email),
                  subtitle: Text(L10n.of(context).authLoginTitle),
                ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(L10n.of(context).authLogout),
                enabled: !isLoggingOut,
                onTap: isLoggingOut ? null : _confirmLogout,
                trailing: isLoggingOut
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 10, 8),
                child: ChangeThemeMode(),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: webdavSwitch(context, setState, ref),
              ),
              const Divider(),
              const MoreSettings(),
              if (EnvVar.enableInAppPurchase)
                ListTile(
                  title: Text(L10n.of(context).iapPageTitle),
                  leading: const Icon(Icons.star_outline),
                  subtitle: Text(ref.watch(iapProvider).maybeWhen(
                        data: (state) => state.status.title(context),
                        orElse: () => L10n.of(context).iapStatusUnknown,
                      )),
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const IAPPage()));
                  },
                ),
              const About(),
            ],
          ),
        ),
      ),
    );
  }
}
