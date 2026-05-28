import 'package:flutter_test/flutter_test.dart';
import 'package:vain_app/features/profile/models/user_profile.dart';

void main() {
  group('UserProfile Tests', () {
    test('copyWith should update new fields', () {
      const profile = UserProfile();
      final updated = profile.copyWith(
        faceShape: FaceShape.oval,
        keyFeatures: ['test1', 'test2'],
      );

      expect(updated.faceShape, FaceShape.oval);
      expect(updated.keyFeatures, ['test1', 'test2']);
    });

    test('fromMap/toMap should handle new fields', () {
      final profile = const UserProfile().copyWith(
        faceShape: FaceShape.round,
        keyFeatures: ['feature1'],
      );

      final map = profile.toMap();
      expect(map['faceShape'], 'round');
      expect(map['keyFeatures'], ['feature1']);

      final fromMap = UserProfile.fromMap(map);
      expect(fromMap.faceShape, FaceShape.round);
      expect(fromMap.keyFeatures, ['feature1']);
    });
  });
}
