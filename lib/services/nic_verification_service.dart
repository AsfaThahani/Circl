import 'dart:io'; 
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

enum VerificationRequired {
  required,
  pending,
  verified,
  skipped,
  notLoggedIn,
}

class NICVerificationService {
  final _supabase = Supabase.instance.client;
  static const String _pepper = EnvConfig.nicPepper;
  
  Future<VerificationRequired> checkVerificationStatus() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return VerificationRequired.notLoggedIn;
    
    try {
      final result = await _supabase
          .from('nic_verifications')
          .select('verification_status')
          .eq('user_id', user.id)
          .maybeSingle();
      
      if (result != null) {
        switch (result['verification_status']) {
          case 'verified':
            return VerificationRequired.verified;
          case 'skipped':
            return VerificationRequired.skipped;
          case 'pending':
            return VerificationRequired.pending;
          default:
            return VerificationRequired.required;
        }
      }
      
      final profile = await _supabase
          .from('profiles')
          .select('is_nic_verified, nic_skipped')
          .eq('id', user.id)
          .maybeSingle();
          
      if (profile != null) {
        if (profile['is_nic_verified'] == true) {
          return VerificationRequired.verified;
        }
        if (profile['nic_skipped'] == true) {
          return VerificationRequired.skipped;
        }
      }
      
      return VerificationRequired.required;
    } catch (e) {
      debugPrint('Error checking NIC status: $e');
      return VerificationRequired.required;
    }
  }
  
  Future<bool> isNICDuplicate(String nicNumber) async {
    final normalized = nicNumber.trim().toUpperCase();
    final hash = _generateHash(normalized);
    
    try {
      try {
        final result = await _supabase
            .rpc('check_duplicate_nic', params: {'nic_hash': hash});
        return result == true;
      } catch (e) {
        final result = await _supabase
            .from('nic_verifications')
            .select('id')
            .eq('nic_hash', hash)
            .neq('verification_status', 'skipped')
            .maybeSingle();
        return result != null;
      }
    } catch (e) {
      debugPrint('Error checking duplicate: $e');
      return false;
    }
  }
  
  String _generateHash(String nicNumber, {String? salt}) {
    final userSalt = salt ?? 'default_salt';
    final toHash = '$_pepper:$nicNumber:$userSalt';
    final bytes = utf8.encode(toHash);
    return sha512.convert(bytes).toString();
  }
  
  Future<void> submitVerification(String nicNumber, {File? nicImage}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    
    final existing = await _supabase
        .from('nic_verifications')
        .select('verification_status')
        .eq('user_id', user.id)
        .maybeSingle();
    
    if (existing != null && existing['verification_status'] == 'verified') {
      throw Exception('Your NIC is already verified');
    }
    
    final isDuplicate = await isNICDuplicate(nicNumber);
    if (isDuplicate) {
      throw Exception('This NIC is already verified with another account');
    }
    
    final nicHash = _generateHash(nicNumber);
    
    String? imageUrl;
    if (nicImage != null) {
      final path = 'temp_nic/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage.from('temp_nic').upload(path, nicImage);
      imageUrl = _supabase.storage.from('temp_nic').getPublicUrl(path);
    }
    
    if (existing != null) {
      await _supabase.from('nic_verifications').update({
        'nic_hash': nicHash,
        'verification_status': 'pending',
        'temp_image_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', user.id);
    } else {
      await _supabase.from('nic_verifications').insert({
        'user_id': user.id,
        'nic_hash': nicHash,
        'verification_status': 'pending',
        'temp_image_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    
    await _supabase
        .from('profiles')
        .update({
          'is_nic_verified': false,
          'nic_skipped': false,
          'verification_status': 'pending',
        })
        .eq('id', user.id);
  }
  
  Future<void> skipVerification() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    
    final existing = await _supabase
        .from('nic_verifications')
        .select('verification_status')
        .eq('user_id', user.id)
        .maybeSingle();
    
    if (existing != null) {
      if (existing['verification_status'] == 'verified') {
        throw Exception('Cannot skip - NIC already verified');
      }
      
      await _supabase
          .from('nic_verifications')
          .update({
            'verification_status': 'skipped',
            'skipped_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', user.id);
    } else {
      await _supabase.from('nic_verifications').insert({
        'user_id': user.id,
        'verification_status': 'skipped',
        'skipped_at': DateTime.now().toIso8601String(),
      });
    }
    
    await _supabase
        .from('profiles')
        .update({
          'nic_skipped': true,
          'is_nic_verified': false,
          'verification_status': 'skipped',
        })
        .eq('id', user.id);
  }
  
  Future<Map<String, dynamic>?> getVerificationDetails() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    
    try {
      return await _supabase
          .from('nic_verifications')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
    } catch (e) {
      debugPrint('Error getting verification details: $e');
      return null;
    }
  }
  
  Future<void> approveVerification(String userId) async {
    try {
      await _supabase.from('nic_verifications').update({
        'verification_status': 'verified',
        'verified_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);
      
      await _supabase.from('profiles').update({
        'is_nic_verified': true,
        'verification_status': 'verified',
      }).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to approve verification: $e');
    }
  }
}
