import 'package:flutter/material.dart';

const Color kTealColor = Color(0xFF26A69A);

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
          color: const Color(0xFF0F172A),
        ),
        title: Text(
          'Privacy Policy',
          style: const TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.bold, 
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black,
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kTealColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Last Updated: June 2026',
                style: TextStyle(
                  fontSize: 11,
                  color: kTealColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: 'Introduction',
              content:
                  'Circl ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and protect your information when you use our mobile application.',
              isDark: isDark,
            ),
            const SizedBox(height: 18),
            _buildSection(
              title: '1. Information We Collect',
              content: [
                '• Email address, password, phone number',
                '• Name, profile picture, bio',
                '• Location and address (with your permission)',
                '• Payment information (processed securely)',
                '',
                'Activity Information:',
                '• Requests you create and respond to',
                '• Reviews and ratings',
                '• Messages and communications',
                '• Transaction history',
                '',
                'Device Information:',
                '• Device type, operating system',
                '• Device ID, IP address',
                '• App usage patterns',
                '• GPS location (when enabled)',
                '',
                'Usage Information:',
                '• Pages visited, features used',
                '• Time spent on features',
                '• Search queries',
                '• Preferences and settings',
              ].join('\n'),
              isDark: isDark,
            ),
            const SizedBox(height: 18),
            _buildSection(
              title: '2. How We Use Your Information',
              content: [
                'We use collected information for:',
                '• Providing and improving our services',
                '• Processing transactions and payments',
                '• Verifying your identity and preventing fraud',
                '• Sending service notifications and updates',
                '• Personalizing your experience',
                '• Analyzing usage patterns for improvements',
                '• Compliance with legal obligations',
                '• Contacting you about your account',
              ].join('\n'),
              isDark: isDark,
            ),
            const SizedBox(height: 18),
            _buildSection(
              title: '3. Data Sharing & Disclosure',
              content: [
                'Your information may be shared with:',
                '• Other users (username, profile, ratings)',
                '• Service providers (payment processors, hosting)',
                '• Legal authorities (when required by law)',
                '• Business partners (with your consent)',
                '',
                'We do NOT:',
                '• Sell your personal data to third parties',
                '• Share your exact location without permission',
                '• Disclose financial information unnecessarily',
                '• Share data for marketing without consent',
              ].join('\n'),
              isDark: isDark,
            ),
            const SizedBox(height: 18),
            _buildSection(
              title: '4. Data Security',
              content: [
                'We implement industry-standard security measures:',
                '• SSL encryption for all data transmission',
                '• Secure password hashing',
                '• Regular security audits',
                '• Access controls and authentication',
                '• Secure cloud storage with Supabase',
                '',
                'However, no system is completely secure. We cannot guarantee absolute security of your data.',
              ].join('\n'),
              isDark: isDark,
            ),
            const SizedBox(height: 18),
            _buildSection(
              title: '5. Location Privacy',
              content: [
                'Location Sharing:',
                '• We only access location when you enable it',
                '• GPS coordinates are stored only for matching',
                '• General location (city/area) shown on profile',
                '• Exact location not shared without permission',
                '',
                'You can:',
                '• Disable location access anytime',
                '• Update your location settings',
                '• Delete saved location data',
                '• Control visibility of your location',
              ].join('\n'),
              isDark: isDark,
            ),
            const SizedBox(height: 18),
            _buildSection(
              title: '6. Your Privacy Rights',
              content: [
                'You have the right to:',
                '• Access your personal data',
                '• Correct inaccurate information',
                '• Request data deletion (right to be forgotten)',
                '• Export your data',
                '• Opt-out of communications',
                '• Control privacy settings',
                '• Withdraw consent anytime',
                '',
                'To exercise these rights, contact us at privacy@circl.app',
              ].join('\n'),
              isDark: isDark,
            ),
            const SizedBox(height: 18),
            _buildSection(
              title: '7. Cookies & Tracking',
              content: [
                'We use:',
                '• Session cookies for authentication',
                '• Analytics to understand usage',
                '• Preference cookies to remember settings',
                '• No third-party tracking cookies',
                '',
                'You can:',
                '• Disable cookies in settings',
                '• Clear cache and cookies',
                '• Opt-out of analytics',
              ].join('\n'),
              isDark: isDark,
            ),
            const SizedBox(height: 18),
            _buildSection(
              title: '8. Third-Party Services',
              content: [
                'We use:',
                '• Supabase for data storage and authentication',
                '• Stripe for payment processing',
                '• Google Analytics for usage analytics',
                '• Firebase for push notifications',
                '',
                'These services have their own privacy policies.',
              ].join('\n'),
              isDark: isDark,
            ),
            const SizedBox(height: 18),
            _buildSection(
              title: '9. Children\'s Privacy',
              content: [
                'Circl is not intended for users under 18 years old.',
                'We do not knowingly collect data from children.',
                'If we discover data from children, we will delete it immediately.',
                '',
                'Parents who believe their child provided data should contact us.',
              ].join('\n'),
              isDark: isDark,
            ),
            const SizedBox(height: 18),
            _buildSection(
              title: '10. Policy Changes',
              content: [
                'We may update this policy periodically.',
                'We will notify you of material changes via:',
                '• In-app notification',
                '• Email notification',
                '• Updated policy date',
                '',
                'Continued use means acceptance of new terms.',
              ].join('\n'),
              isDark: isDark,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kTealColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: kTealColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Questions About Privacy?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If you have concerns or questions about our privacy practices, please contact us:',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildContactItem(
                    icon: Icons.mail_outline,
                    label: 'Email',
                    value: 'privacy@circl.app',
                    isDark: isDark,
                  ),
                  _buildContactItem(
                    icon: Icons.language,
                    label: 'Website',
                    value: 'www.circl.app/privacy',
                    isDark: isDark,
                  ),
                  _buildContactItem(
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: 'Kandy, Sri Lanka',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title, 
    required String content,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
              height: 1.8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kTealColor),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: kTealColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}