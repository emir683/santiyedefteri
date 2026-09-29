import 'package:flutter/material.dart';

/// Tek bir tur adımını tanımlayan veri modeli.
class TourStep {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final GlobalKey? targetKey;
  final EdgeInsets targetPadding;
  final double targetBorderRadius;
  final VoidCallback? onStepEnter;

  const TourStep({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.targetKey,
    this.targetPadding = const EdgeInsets.all(8),
    this.targetBorderRadius = 16.0,
    this.onStepEnter,
  });
}
