class VirtualPin {
  final String id;
  final int pin_id;
  final String pin_name;
  final int value;
  final int min_value;
  final int max_value;
  final bool is_used;

  VirtualPin({
    required this.id,
    required this.pin_id,
    required this.pin_name,
    required this.value,
    this.min_value = 0,
    this.max_value = 100,
    this.is_used = false,
  });

  factory VirtualPin.fromJson(Map<String, dynamic> json) {
    // Generate a unique ID if none is provided
    String id = json['_id'] as String? ?? '';
    if (id.isEmpty) {
      id = 'vpin_${DateTime.now().millisecondsSinceEpoch}_${json['pin_id'] ?? 0}';
    }
    
    return VirtualPin(
      id: id,
      pin_id: json['pin_id'] as int? ?? 0,
      pin_name: json['pin_name'] as String? ?? 'Virtual Pin',
      value: json['value'] as int? ?? 0,
      min_value: json['min_value'] as int? ?? 0,
      max_value: json['max_value'] as int? ?? 100,
      is_used: json['is_used'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'pin_id': pin_id,
      'pin_name': pin_name,
      'value': value,
      'min_value': min_value,
      'max_value': max_value,
      'is_used': is_used,
    };
  }

  VirtualPin copyWith({
    String? id,
    int? pin_id,
    String? pin_name,
    int? value,
    int? min_value,
    int? max_value,
    bool? is_used,
  }) {
    return VirtualPin(
      id: id ?? this.id,
      pin_id: pin_id ?? this.pin_id,
      pin_name: pin_name ?? this.pin_name,
      value: value ?? this.value,
      min_value: min_value ?? this.min_value,
      max_value: max_value ?? this.max_value,
      is_used: is_used ?? this.is_used,
    );
  }
} 