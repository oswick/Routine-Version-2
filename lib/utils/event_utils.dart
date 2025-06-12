import 'package:flutter/material.dart';

// Funciones para manejar la importancia (prioridad)
Color getImportanceColor(int importance) {
  switch (importance) {
    case 1:
      return Colors.green;
    case 2:
      return Colors.yellow.shade700; // Usamos un amarillo más oscuro para mejor visibilidad
    case 3:
      return Colors.orange;
    case 4:
      return Colors.red;
    default:
      return Colors.transparent; // Color por defecto para cuando no hay prioridad
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

// Funciones para manejar categorías
Color getCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'school':
      return Colors.blue;
    case 'home':
      return Colors.green;
    case 'work':
      return Colors.orange;
    case 'shopping':
      return Colors.purple;
    case 'health':
      return Colors.red;
    case 'personal':
      return Colors.teal;
    default:
      return Colors.transparent; // Color por defecto para categorías no especificadas
  }
}

IconData getCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'school':
      return Icons.school;
    case 'home':
      return Icons.home;
    case 'work':
      return Icons.work;
    case 'shopping':
      return Icons.shopping_cart;
    case 'health':
      return Icons.health_and_safety;
    case 'personal':
      return Icons.person;
    default:
      return Icons.category; // Icono por defecto para categorías no especificadas
  }
}

// Función adicional para manejar días de repetición
String getDayName(int dayOfWeek) {
  switch (dayOfWeek) {
    case 1:
      return 'Monday';
    case 2:
      return 'Tuesday';
    case 3:
      return 'Wednesday';
    case 4:
      return 'Thursday';
    case 5:
      return 'Friday';
    case 6:
      return 'Saturday';
    case 7:
      return 'Sunday';
    default:
      return '';
  }
}

String formatTime(DateTime dateTime) {
  return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}
