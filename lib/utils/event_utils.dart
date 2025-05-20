import 'package:flutter/material.dart';

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
    default:
      return Colors.transparent;
  }
}

IconData getCategoryIcon(String category) {
  switch (category) {
    case 'School':
      return Icons.school;
    case 'Home':
      return Icons.home;
    case 'Work':
      return Icons.work;
    case 'Shopping':
      return Icons.shopping_cart;
    default:
      return Icons.close;
  }
}
