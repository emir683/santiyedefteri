import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelManager {
  static Future<void> initialize() async {}
}

class ModelInfo {
  final String id;
  final String name;
  final String provider;
  final String modelId;
  final int maxTokens;
  final int trainingCost;
  final int outputCost;
  final int? inputCostPer1M;

  ModelInfo({
    required this.id,
    required this.name,
    required this.provider,
    required this.modelId,
    required this.maxTokens,
    required this.trainingCost,
    required this.outputCost,
    this.inputCostPer1M,
  });

  factory ModelInfo.fromMap(String id, Map<String, dynamic> map) {
    return ModelInfo(
      id: id,
      name: map['name'] as String? ?? 'Unknown Model',
      provider: map['provider'] as String? ?? 'unknown',
      modelId: map['modelId'] as String? ?? '',
      maxTokens: (map['maxTokens'] as num?)?.toInt() ?? 128000,
      trainingCost: (map['trainingCost'] as num?)?.toInt() ?? 0,
      outputCost: (map['outputCost'] as num?)?.toInt() ?? 0,
      inputCostPer1M: (map['inputCostPer1M'] as num?)?.toInt(),
    );
  }
}
