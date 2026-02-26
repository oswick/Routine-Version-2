// lib/utils/event_utils.dart
//
// IMPORTANT: Categories are stored as fixed English keys in the database
// ("School", "Home", "Work", etc.). They are only translated for display.
// Never store localized strings as category values.

import 'package:flutter/material.dart';
import 'package:myapp/l10n/app_localizations.dart';

// Fixed category keys — these are the values stored in the DB.
class CategoryKeys {
  static const String school = 'School';
  static const String home = 'Home';
  static const String work = 'Work';
  static const String shopping = 'Shopping';
  static const String health = 'Health';
  static const String personal = 'Personal';

  static const List<String> all = [
    school,
    home,
    work,
    shopping,
    health,
    personal,
  ];
}

/// Returns the localized display name for a category key.
/// Falls back to the key itself if not recognized.
String getCategoryDisplayName(String categoryKey, BuildContext context) {
  final l10n = AppLocalizations.of(context);
  switch (categoryKey) {
    case CategoryKeys.school:
      return l10n.school;
    case CategoryKeys.home:
      return l10n.home;
    case CategoryKeys.work:
      return l10n.work;
    case CategoryKeys.shopping:
      return l10n.shopping;
    case CategoryKeys.health:
      return l10n.health;
    case CategoryKeys.personal:
      return l10n.personal;
    default:
      return categoryKey;
  }
}

Color getImportanceColor(int importance) {
  switch (importance) {
    case 1:
      return Colors.green;
    case 2:
      return Colors.yellow;
    case 3:
      return Colors.orange;
    case 4:
      return Colors.red;
    default:
      return Colors.transparent;
  }
}

String getImportanceText(int importance, BuildContext context) {
  final l10n = AppLocalizations.of(context);
  switch (importance) {
    case 1:
      return l10n.low;
    case 2:
      return l10n.moderate;
    case 3:
      return l10n.important;
    case 4:
      return l10n.veryImportant;
    default:
      return l10n.none;
  }
}

/// Returns the icon for a category key (always uses English keys).
IconData getCategoryIcon(String categoryKey, [BuildContext? context]) {
  // Normalize: if somehow a localized name was passed, try to reverse-map it.
  final normalizedKey =
      context != null ? _normalizeCategory(categoryKey, context) : categoryKey;

  switch (normalizedKey) {
    case CategoryKeys.school:
      return Icons.school;
    case CategoryKeys.home:
      return Icons.home;
    case CategoryKeys.work:
      return Icons.work;
    case CategoryKeys.shopping:
      return Icons.shopping_cart;
    case CategoryKeys.health:
      return Icons.health_and_safety;
    case CategoryKeys.personal:
      return Icons.person;
    default:
      return Icons.menu;
  }
}

/// Attempts to map a possibly-localized category string back to an English key.
/// This is a compatibility shim for events saved with old localized values.
String _normalizeCategory(String category, BuildContext context) {
  // Already a valid key
  if (CategoryKeys.all.contains(category)) return category;

  // Try to map from localized name
  final l10n = AppLocalizations.of(context);
  if (category == l10n.school) return CategoryKeys.school;
  if (category == l10n.home) return CategoryKeys.home;
  if (category == l10n.work) return CategoryKeys.work;
  if (category == l10n.shopping) return CategoryKeys.shopping;
  if (category == l10n.health) return CategoryKeys.health;
  if (category == l10n.personal) return CategoryKeys.personal;

  // Also check Spanish hardcoded values (for migration of old data)
  switch (category) {
    case 'Escuela':
      return CategoryKeys.school;
    case 'Casa':
    case 'Inicio':
      return CategoryKeys.home;
    case 'Trabajo':
      return CategoryKeys.work;
    case 'Compras':
      return CategoryKeys.shopping;
    case 'Salud':
      return CategoryKeys.health;
    case 'Personal':
      return CategoryKeys.personal;
  }

  return category;
}