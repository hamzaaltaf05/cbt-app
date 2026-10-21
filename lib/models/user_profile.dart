enum UserRole { admin, shopManager, simpleUser }

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.shopManager:
        return 'shop_manager';
      case UserRole.simpleUser:
        return 'employee';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.shopManager:
        return 'Shop Manager';
      case UserRole.simpleUser:
        return 'Simple User';
    }
  }

  static UserRole fromLabel(String? label) {
    switch (label) {
      case 'admin':
        return UserRole.admin;
      case 'shop_manager':
        return UserRole.shopManager;
      case 'employee':
      default:
        return UserRole.simpleUser;
    }
  }
}

class UserProfile {
  final String id;
  final String fullName;
  final UserRole role;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String? ?? '',
      role: UserRoleLabel.fromLabel(map['role'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'full_name': fullName,
      'role': role.label,
    };
  }
}