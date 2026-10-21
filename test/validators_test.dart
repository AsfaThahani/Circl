// test/validators_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:circl/utils/validators.dart';

void main() {
  group('isValidEmail', () {
    test('accepts a standard email', () {
      expect(isValidEmail('user@circl.com'), true);
    });

    test('rejects an email without domain', () {
      expect(isValidEmail('user@'), false);
    });

    test('rejects an email without @', () {
      expect(isValidEmail('usercircl.com'), false);
    });

    test('rejects an empty string', () {
      expect(isValidEmail(''), false);
    });
  });

  group('isValidPassword', () {
    test('accepts a compliant password', () {
      expect(isValidPassword('SecurePass123'), true);
    });

    test('rejects a password shorter than 8 characters', () {
      expect(isValidPassword('Abc1'), false);
    });

    test('rejects a password longer than 15 characters', () {
      expect(isValidPassword('Abcdefghijklmnop1'), false);
    });

    test('rejects a password with no uppercase letter', () {
      expect(isValidPassword('securepass123'), false);
    });

    test('rejects a password with no digit', () {
      expect(isValidPassword('SecurePass'), false);
    });
  });

  group('isValidBudget', () {
    test('accepts a positive number', () {
      expect(isValidBudget('500'), true);
    });

    test('accepts a decimal number', () {
      expect(isValidBudget('500.50'), true);
    });

    test('rejects zero', () {
      expect(isValidBudget('0'), false);
    });

    test('rejects negative values', () {
      expect(isValidBudget('-100'), false);
    });

    test('rejects non-numeric text', () {
      expect(isValidBudget('abc'), false);
    });
  });

  group('isValidRadius', () {
    test('accepts 1 km (lower bound)', () {
      expect(isValidRadius(1.0), true);
    });

    test('accepts 50 km (upper bound)', () {
      expect(isValidRadius(50.0), true);
    });

    test('rejects 0 km', () {
      expect(isValidRadius(0.0), false);
    });

    test('rejects 51 km', () {
      expect(isValidRadius(51.0), false);
    });
  });
}