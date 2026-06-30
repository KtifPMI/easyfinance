class Tag {
  final String id;
  final String name;

  Tag({required this.id, required this.name});

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? json['title']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
