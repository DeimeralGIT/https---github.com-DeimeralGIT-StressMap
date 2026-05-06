import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  static const _languages = [
    _LanguageOption(locale: Locale('en'), labelKey: 'settings.english'),
    _LanguageOption(locale: Locale('es'), labelKey: 'settings.spanish'),
    _LanguageOption(locale: Locale('pt'), labelKey: 'settings.portuguese'),
    _LanguageOption(locale: Locale('fr'), labelKey: 'settings.french'),
    _LanguageOption(locale: Locale('ru'), labelKey: 'settings.russian'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'settings.title'.tr(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'settings.language'.tr(),
                style: const TextStyle(
                  color: Color(0xFFC4CEDA),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              for (final language in _languages)
                _LanguageTile(
                  language: language,
                  groupValue: currentLocale.languageCode,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.groupValue,
  });

  final _LanguageOption language;
  final String groupValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121A26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          context.setLocale(language.locale);
          Navigator.of(context).pop();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  language.labelKey.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                language.locale.languageCode == groupValue
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: language.locale.languageCode == groupValue
                    ? const Color(0xFF35D07F)
                    : const Color(0xFF8290A3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption {
  const _LanguageOption({
    required this.locale,
    required this.labelKey,
  });

  final Locale locale;
  final String labelKey;
}
