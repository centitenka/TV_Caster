import 'package:hive/hive.dart';

part 'video_source.g.dart';

@HiveType(typeId: 0)
class VideoSource {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String url;
  
  @HiveField(3)
  final String? thumbnail;
  
  @HiveField(4)
  final String? description;
  
  @HiveField(5)
  final DateTime createdAt;
  
  @HiveField(6)
  final String? ruleId;

  VideoSource({
    required this.id,
    required this.name,
    required this.url,
    this.thumbnail,
    this.description,
    required this.createdAt,
    this.ruleId,
  });

  factory VideoSource.fromJson(Map<String, dynamic> json) {
    return VideoSource(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      thumbnail: json['thumbnail'],
      description: json['description'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      ruleId: json['ruleId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'thumbnail': thumbnail,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'ruleId': ruleId,
    };
  }
}
