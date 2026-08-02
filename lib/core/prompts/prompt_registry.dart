import 'dart:convert';

import 'package:flutter/services.dart';

class PromptTemplate {
  const PromptTemplate({
    required this.id,
    required this.version,
    required this.schemaVersion,
    required this.system,
    required this.outputContract,
  });

  final String id;
  final int version;
  final int schemaVersion;
  final String system;
  final Map<String, dynamic> outputContract;

  factory PromptTemplate.fromJson(Map<String, dynamic> json) {
    return PromptTemplate(
      id: json['id'] as String,
      version: json['version'] as int,
      schemaVersion: json['schema_version'] as int,
      system: json['system'] as String,
      outputContract: json['output_contract'] as Map<String, dynamic>,
    );
  }
}

class PromptRegistry {
  const PromptRegistry();

  Future<PromptTemplate> load(String id) async {
    final raw = await rootBundle.loadString('assets/prompts/$id.v1.json');
    return PromptTemplate.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
