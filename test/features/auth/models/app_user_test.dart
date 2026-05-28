import 'package:flutter_test/flutter_test.dart';
import 'package:vain_app/features/auth/models/app_user.dart';
import 'package:vain_app/features/auth/models/profile_preferences.dart';

void main() {
  group('AppUser Model Tests', () {
    final now = DateTime.now();
    final testUser = AppUser(
      uid: '123',
      email: 'test@example.com',
      name: 'Test User',
      nickname: 'Tester',
      createdAt: now,
      updatedAt: now,
      profilePreferences: ProfilePreferences.empty(),
    );

    test('should convert to map correctly', () {
      final map = testUser.toMap();
      expect(map['email'], 'test@example.com');
      expect(map['name'], 'Test User');
      expect(map['nickname'], 'Tester');
    });

    test('should create from map correctly', () {
      final map = {
        'uid': '123',
        'email': 'test@example.com',
        'name': 'Test User',
        'nickname': 'Tester',
        'createdAt': now,
        'updatedAt': now,
        'profilePreferences': {},
      };
      final user = AppUser.fromMap(map);
      expect(user.uid, '123');
      expect(user.name, 'Test User');
      expect(user.nickname, 'Tester');
    });

    test('copyWith should update fields correctly', () {
      final updatedUser = testUser.copyWith(nickname: 'NewNick');
      expect(updatedUser.nickname, 'NewNick');
      expect(updatedUser.name, 'Test User'); // Should remain same
    });
  });
}
