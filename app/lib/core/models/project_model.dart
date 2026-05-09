class ProjectModel {
  final String id;
  final String name;
  final String? description;
  final String? teamId;
  final bool isActive;

  const ProjectModel({
    required this.id,
    required this.name,
    this.description,
    this.teamId,
    this.isActive = true,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) => ProjectModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        teamId: json['teamId'] as String?,
        isActive: json['isActive'] as bool? ?? true,
      );
}
