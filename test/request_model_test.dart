// test/request_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:circl/models/request_model.dart';

void main() {
  final sampleJson = {
    'request_id': 'req-001',
    'requester_id': 'user-abc',
    'type': 'Free Borrow',
    'title': 'Drill Tool',
    'description': 'Need a power drill for 2 hours',
    'amount': null,
    'latitude': 6.9271,
    'longitude': 79.8612,
    'radius_km': 2,
    'status': 'open',
  };

  group('RequestModel.fromJson', () {
    test('parses all required fields correctly', () {
      final r = RequestModel.fromJson(sampleJson);
      expect(r.requestId, 'req-001');
      expect(r.requesterId, 'user-abc');
      expect(r.type, 'Free Borrow');
      expect(r.title, 'Drill Tool');
      expect(r.radiusKm, 2);
      expect(r.status, 'open');
    });

    test('handles null amount for free requests', () {
      final r = RequestModel.fromJson(sampleJson);
      expect(r.amount, isNull);
    });

    test('parses numeric amount for paid requests', () {
      final paid = Map<String, dynamic>.from(sampleJson)
        ..['type'] = 'Paid Rent'
        ..['amount'] = 1500.50;
      final r = RequestModel.fromJson(paid);
      expect(r.amount, 1500.50);
    });
  });

  group('RequestModel.toJson', () {
    test('round-trips cleanly (fromJson -> toJson -> fromJson)', () {
      final original = RequestModel.fromJson(sampleJson);
      final round = RequestModel.fromJson(original.toJson());
      expect(round.requestId, original.requestId);
      expect(round.type, original.type);
      expect(round.latitude, original.latitude);
    });
  });

  group('RequestModel helpers', () {
    test('isFree returns true for Free Borrow', () {
      final r = RequestModel.fromJson(sampleJson);
      expect(r.isFree, true);
      expect(r.isPaid, false);
    });

    test('isPaid returns true for Paid Rent', () {
      final paid = Map<String, dynamic>.from(sampleJson)
        ..['type'] = 'Paid Rent'
        ..['amount'] = 500.0;
      final r = RequestModel.fromJson(paid);
      expect(r.isPaid, true);
      expect(r.isFree, false);
    });
  });
}