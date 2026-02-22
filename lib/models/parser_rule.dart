import 'package:hive/hive.dart';

part 'parser_rule.g.dart';

@HiveType(typeId: 1)
class ParserRule {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String host;
  
  @HiveField(3)
  final List<RuleItem> rules;
  
  @HiveField(4)
  final Map<String, String>? headers;
  
  @HiveField(5)
  final bool isEnabled;
  
  @HiveField(6)
  final DateTime createdAt;
  
  @HiveField(7)
  final String? description;

  ParserRule({
    required this.id,
    required this.name,
    required this.host,
    required this.rules,
    this.headers,
    this.isEnabled = true,
    required this.createdAt,
    this.description,
  });

  factory ParserRule.fromJson(Map<String, dynamic> json) {
    return ParserRule(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      host: json['host'] ?? '',
      rules: (json['rules'] as List?)
              ?.map((r) => RuleItem.fromJson(r))
              .toList() ??
          [],
      headers: (json['headers'] as Map?)?.cast<String, String>(),
      isEnabled: json['isEnabled'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'rules': rules.map((r) => r.toJson()).toList(),
      'headers': headers,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
      'description': description,
    };
  }
}

@HiveType(typeId: 2)
class RuleItem {
  @HiveField(0)
  final String name;
  
  @HiveField(1)
  final String xpath;
  
  @HiveField(2)
  final String? attribute;
  
  @HiveField(3)
  final String? regex;
  
  @HiveField(4)
  final String? replacement;

  RuleItem({
    required this.name,
    required this.xpath,
    this.attribute,
    this.regex,
    this.replacement,
  });

  factory RuleItem.fromJson(Map<String, dynamic> json) {
    return RuleItem(
      name: json['name'] ?? '',
      xpath: json['xpath'] ?? '',
      attribute: json['attribute'],
      regex: json['regex'],
      replacement: json['replacement'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'xpath': xpath,
      'attribute': attribute,
      'regex': regex,
      'replacement': replacement,
    };
  }
}

enum RuleType {
  search,
  detail,
  episode,
  video,
}
