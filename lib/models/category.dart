import 'package:flutter/material.dart';
class ClipCategory {
  final String id;
  final String name;
  final Color color;
  final IconData icon;
  final int position;
  const ClipCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.position = 0,
  });
  ClipCategory copyWith({int? position}) => ClipCategory(
        id: id,
        name: name,
        color: color,
        icon: icon,
        position: position ?? this.position,
      );
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color.toARGB32(),
        'icon': icon.codePoint,
        'position': position,
      };
  factory ClipCategory.fromMap(Map<String, dynamic> map) => ClipCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        color: Color(map['color'] as int),
        // ignore: non_const_argument_for_const_parameter
        icon: IconData(map['icon'] as int, fontFamily: 'MaterialIcons'),
        position: map['position'] as int? ?? 0,
      );
}
