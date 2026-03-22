class Room {
  final String id;
  final String code;
  final String name;
  final String? building;
  final int? floor;
  final int? capacity;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Room({
    required this.id,
    required this.code,
    required this.name,
    this.building,
    this.floor,
    this.capacity,
    required this.createdAt,
    this.updatedAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      building: json['building'] as String?,
      floor: json['floor'] as int?,
      capacity: json['capacity'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'building': building,
      'floor': floor,
      'capacity': capacity,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Room copyWith({
    String? id,
    String? code,
    String? name,
    String? building,
    int? floor,
    int? capacity,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Room(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      capacity: capacity ?? this.capacity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayName {
    final parts = <String>[];
    if (building != null && building!.isNotEmpty) parts.add(building!);
    parts.add(name);
    return parts.join(' - ');
  }

  @override
  String toString() => 'Room(id: $id, code: $code, name: $name)';
}
