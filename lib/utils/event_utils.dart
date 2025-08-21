import 'package:flutter/material.dart';
import 'package:myapp/l10n/app_localizations.dart';

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

String getImportanceText(int importance) {
  switch (importance) {
    case 1:
      return 'Low';
    case 2:
      return 'Moderate';
    case 3:
      return 'Important';
    case 4:
      return 'Very Important';
    default:
      return 'None';
  }
}

Color getCategoryColor(String category) {
  switch (category) {
    case 'School':
      return Colors.transparent;
    case 'Home':
      return Colors.transparent;
    case 'Work':
      return Colors.transparent;
    case 'Shopping':
      return Colors.transparent;
    case 'Health':
      return Colors.transparent;
    case 'Personal':
      return Colors.transparent;
    default:
      return Colors.transparent;
  }
}

// Función mejorada que maneja categorías localizadas
IconData getCategoryIcon(String category, [BuildContext? context]) {
  // Si no hay contexto, usar comparación en inglés (fallback)
  if (context == null) {
    return _getCategoryIconByEnglishName(category);
  }

  // Obtener las traducciones del contexto actual
  final localizations = AppLocalizations.of(context);
  
  // Comparar con las traducciones localizadas
  if (category == localizations.school) {
    return Icons.school;
  } else if (category == localizations.home) {
    return Icons.home;
  } else if (category == localizations.work) {
    return Icons.work;
  } else if (category == localizations.shopping) {
    return Icons.shopping_cart;
  } else if (category == localizations.health) {
    return Icons.health_and_safety;
  } else if (category == localizations.personal) {
    return Icons.person;
  }
  
  // Fallback: intentar comparación en inglés
  return _getCategoryIconByEnglishName(category);
}

// Función auxiliar para comparación en inglés (para compatibilidad)
IconData _getCategoryIconByEnglishName(String category) {
  switch (category) {
    case 'School':
      return Icons.school;
    case 'Home':
      return Icons.home;
    case 'Work':
      return Icons.work;
    case 'Shopping':
      return Icons.shopping_cart;
    case 'Health':
      return Icons.health_and_safety;
    case 'Personal':
      return Icons.person;
    default:
      return Icons.menu;
  }
}