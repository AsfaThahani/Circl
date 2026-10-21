// test/circl_utils_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:circl/utils/circl_utils.dart';

void main() {
  group('haversineDistance', () {
    test('returns approx 11.3 km for two known Colombo coordinates', () {
      final d = haversineDistance(6.9271, 79.8612, 6.8483, 79.9265);
      expect(d, closeTo(11.3, 0.3));
    });

    test('returns 0 for identical points', () {
      final d = haversineDistance(6.9, 79.8, 6.9, 79.8);
      expect(d, closeTo(0.0, 0.001));
    });

    test('is symmetric — order of points does not matter', () {
      final a = haversineDistance(6.9271, 79.8612, 6.8483, 79.9265);
      final b = haversineDistance(6.8483, 79.9265, 6.9271, 79.8612);
      expect(a, closeTo(b, 0.001));
    });
  });

  group('auraLevelFor', () {
    test('0 points = Bronze', () {
      expect(auraLevelFor(0), 'Bronze');
    });

    test('100 points = Silver (lower boundary)', () {
      expect(auraLevelFor(100), 'Silver');
    });

    test('250 points = Gold (lower boundary)', () {
      expect(auraLevelFor(250), 'Gold');
    });

    test('500 points = Diamond (lower boundary)', () {
      expect(auraLevelFor(500), 'Diamond');
    });

    test('negative points default to Bronze', () {
      expect(auraLevelFor(-50), 'Bronze');
    });
  });

  group('circlPointsForCompletion', () {
    test('Paid Rent earns base 5 points only', () {
      expect(circlPointsForCompletion(requestType: 'Paid Rent'), 5);
    });

    test('Free Favour earns 10 points (5 base + 5 bonus)', () {
      expect(circlPointsForCompletion(requestType: 'Free Favour'), 10);
    });

    test('Free Borrow earns 10 points (5 base + 5 bonus)', () {
      expect(circlPointsForCompletion(requestType: 'Free Borrow'), 10);
    });
  });

  group('platformCommission', () {
    test('5% commission on LKR 1000 = 50', () {
      expect(platformCommission(1000), 50.0);
    });

    test('returns 0 for zero or negative amounts', () {
      expect(platformCommission(0), 0.0);
      expect(platformCommission(-100), 0.0);
    });
  });
}