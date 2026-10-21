import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class ProfileService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> updates, String userId) async {
    try {
      await _supabase
          .from('profiles')
          .update({
            ...updates,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      debugPrint('✅ Profile updated for user: $userId');
    } catch (e) {
      debugPrint('❌ Error updating profile: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyRequests(String userId) async {
    try {
      final response = await _supabase
          .from('requests')
          .select('*')
          .eq('requester_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching requests: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAcceptedRequests(String userId) async {
    try {
      final response = await _supabase
          .from('requests')
          .select('*')
          .eq('helper_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching accepted requests: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyReviews(String userId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('*, reviewer:profiles!reviews_reviewer_id_fkey(username)')
          .eq('reviewee_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
      return [];
    }
  }

  Future<void> updateUserLocation(String userId, double latitude, double longitude) async {
    try {
      await _supabase
          .from('profiles')
          .update({
            'latitude': latitude,
            'longitude': longitude,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      debugPrint('✅ Location updated for user: $userId');
    } catch (e) {
      debugPrint('❌ Error updating location: $e');
      rethrow;
    }
  }

  Future<void> updateLocationText(String userId, String location) async {
    try {
      await _supabase
          .from('profiles')
          .update({
            'location': location,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      debugPrint('✅ Location text updated for user: $userId');
    } catch (e) {
      debugPrint('❌ Error updating location text: $e');
      rethrow;
    }
  }

  Future<void> updateHomeAddress(String userId, String address) async {
    try {
      await _supabase
          .from('profiles')
          .update({
            'home_address': address,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      debugPrint('✅ Home address updated for user: $userId');
    } catch (e) {
      debugPrint('❌ Error updating home address: $e');
      rethrow;
    }
  }

  Future<Map<String, double>?> getUserLocation(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('latitude, longitude')
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null && 
          response['latitude'] != null && 
          response['longitude'] != null) {
        return {
          'latitude': (response['latitude'] as num).toDouble(),
          'longitude': (response['longitude'] as num).toDouble(),
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user location: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchProfileWithLocation(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('*, latitude, longitude, location, home_address')
          .eq('id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error fetching profile with location: $e');
      return null;
    }
  }

  Future<bool> hasLocationSet(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('latitude, longitude')
          .eq('id', userId)
          .maybeSingle();
      
      return response != null && 
             response['latitude'] != null && 
             response['longitude'] != null;
    } catch (e) {
      debugPrint('Error checking location: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getUsersNearLocation(
    double latitude, 
    double longitude, 
    double radiusKm
  ) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, username, latitude, longitude')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);
      
      final List<Map<String, dynamic>> nearby = [];
      for (var profile in response) {
        final lat = (profile['latitude'] as num).toDouble();
        final lon = (profile['longitude'] as num).toDouble();
        final distance = _calculateDistance(latitude, longitude, lat, lon);
        if (distance <= radiusKm) {
          nearby.add(profile);
        }
      }
      
      return nearby;
    } catch (e) {
      debugPrint('Error getting users near location: $e');
      return [];
    }
  }

  Future<double> fetchWalletBalance(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('wallet_balance')
          .eq('id', userId)
          .maybeSingle();

      if (response != null && response['wallet_balance'] != null) {
        return (response['wallet_balance'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error fetching wallet balance: $e');
      return 0.0;
    }
  }

  Future<bool> submitDispute({
    required String userId,
    required String requestId,
    required String reason,
    required String description,
  }) async {
    try {
      await _supabase.from('disputes').insert({
        'user_id': userId,
        'request_id': requestId,
        'reason': reason,
        'description': description,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ Dispute submitted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error submitting dispute: $e');
      return false;
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = 
        (_sin(dLat / 2) * _sin(dLat / 2)) +
        (_cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) * 
        _sin(dLon / 2) * _sin(dLon / 2));
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;
  double _sin(double x) => sin(x);
  double _cos(double x) => cos(x);
  double _sqrt(double x) => sqrt(x);
  double _atan2(double a, double b) => atan2(a, b);
}
