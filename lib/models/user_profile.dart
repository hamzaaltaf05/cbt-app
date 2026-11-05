import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole {
  admin('admin', 'Admin'),
  shopManager('shop_manager', 'Shop Manager'),
  simpleUser('employee', 'Simple User'),
  officeAdmin('office_admin', 'Office Admin');

  const UserRole(this.value, this.displayName);
  final String value;
  final String displayName;

  String get icon {
    switch (this) {
      case admin:
        return '👑';
      case shopManager:
        return '🏪';
      case simpleUser:
        return '👤';
      case officeAdmin:
        return '🏢';
    }
  }

  static UserRole fromValue(String? value) {
    switch (value) {
      case 'admin':
        return admin;
      case 'shop_manager':
        return shopManager;
      case 'employee':
        return simpleUser;
      case 'office_admin':
        return officeAdmin;
      default:
        return simpleUser;
    }
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.photoUrl,
    this.phone,
  });

  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? photoUrl;
  final String? phone;

  bool get isAdmin => role == UserRole.admin;
  bool get isShopManager => role == UserRole.shopManager;
  bool get isOfficeAdmin => role == UserRole.officeAdmin;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      email: map['email'] as String,
      fullName: map['full_name'] as String,
      role: UserRole.fromValue(map['role']),
      photoUrl: map['photo_url'] as String?,
      phone: map['phone'] as String?,
    );
  }

  static UserProfile fromSession({required User user, required Map<String, dynamic> profile}) {
    return UserProfile(
      id: user.id,
      email: user.email ?? '',
      fullName: profile['full_name'] as String? ?? user.email?.split('@').first ?? 'User',
      role: UserRole.fromValue(profile['role']),
      photoUrl: profile['photo_url'] as String?,
      phone: profile['phone'] as String?,
    );
  }
}