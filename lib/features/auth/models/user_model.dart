class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? departmentId;
  final String? departmentName;
  final bool isActive;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.departmentId,
    this.departmentName,
    required this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      departmentId: json['department_id'] as String?,
      departmentName: json['department_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'department_id': departmentId,
      'department_name': departmentName,
      'is_active': isActive,
    };
  }

  bool get isPlatformAdmin => role == 'platform_admin';
  bool get isDepartmentAdmin => role == 'department_admin';
  bool get isDispatcher => role == 'dispatcher';
  bool get isMaintenance => role == 'maintenance';
  bool get isAnalyst => role == 'analyst';

  // Alert acknowledgment is strictly authorized for platform_admin, department_admin, dispatcher
  bool get canAcknowledgeAlerts =>
      isPlatformAdmin || isDepartmentAdmin || isDispatcher;
}
