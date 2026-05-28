import 'package:flutter/material.dart';

class ClipCategory {
  final String id;
  final String name;
  final Color color;
  final IconData icon;

  const ClipCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color.toARGB32(),
        'icon': icon.codePoint,
      };

  factory ClipCategory.fromMap(Map<String, dynamic> map) => ClipCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        color: Color(map['color'] as int),
        icon: IconData(map['icon'] as int, fontFamily: 'MaterialIcons'),
      );
}
