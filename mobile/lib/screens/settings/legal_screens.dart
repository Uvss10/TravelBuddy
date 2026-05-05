import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A clean, white-themed Privacy Policy screen.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: const [
          _PolicyHeader(
            icon: Icons.privacy_tip_outlined,
            title: 'TravelBuddy Privacy Policy',
            subtitle: 'Last updated: April 2026',
          ),
          SizedBox(height: 24),
          _Section(
            title: '1. Information We Collect',
            content:
                'TravelBuddy collects only the information you provide directly to the app, such as your name and email during sign-up. '
                'Photos you upload for reel generation are processed locally and are not stored on our servers beyond the session unless you explicitly choose to save them. '
                'We do not collect location data without your explicit permission.',
          ),
          _Section(
            title: '2. How We Use Your Information',
            content:
                'We use your information solely to provide and improve the TravelBuddy experience. '
                'Your travel plans, itineraries, and reels are stored locally on your device. '
                'If you use cloud features, data is securely stored in your personal account and is never shared with third parties for advertising.',
          ),
          _Section(
            title: '3. Data Storage & Security',
            content:
                'Your data is stored locally on your device using secure encrypted storage. '
                'If cloud sync is enabled, data is encrypted in transit and at rest. '
                'We use industry-standard security measures to protect your personal information from unauthorized access or disclosure.',
          ),
          _Section(
            title: '4. Third-Party Services',
            content:
                'TravelBuddy uses the following third-party services:\n'
                '• Groq AI: For generating travel itineraries and stories (no personal data is shared beyond your trip inputs).\n'
                '• Wikivoyage: For destination information (public data, no tracking).\n'
                '• IP-based location: Used only to show your approximate city name on the home screen.',
          ),
          _Section(
            title: '5. Photos & Media',
            content:
                'Photos you upload for reel creation are processed on your local device or our backend server during the session only. '
                'Processed images and reels are saved to your device or your designated cloud storage. '
                'We do not use your photos for any purpose other than generating your requested reels.',
          ),
          _Section(
            title: '6. Children\'s Privacy',
            content:
                'TravelBuddy is not directed to children under the age of 13. '
                'We do not knowingly collect personal information from children. '
                'If you believe a child has provided us with personal information, please contact us so we can delete it.',
          ),
          _Section(
            title: '7. Your Rights',
            content:
                'You have the right to:\n'
                '• Access all data stored about you.\n'
                '• Delete your account and all associated data at any time.\n'
                '• Opt out of any optional data collection features.\n'
                'To exercise these rights, use the account deletion option in Settings or contact our support team.',
          ),
          _Section(
            title: '8. Changes to This Policy',
            content:
                'We may update this Privacy Policy periodically. '
                'Any changes will be reflected in the app via the update notification system. '
                'Continued use of TravelBuddy after changes are made constitutes your acceptance of the updated policy.',
          ),
          _Section(
            title: '9. Contact Us',
            content:
                'If you have any questions about this Privacy Policy or your data, please contact us at:\n'
                'support@travelbuddy.app\n\n'
                'We aim to respond to all inquiries within 48 hours.',
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// A clean, white-themed Terms of Service screen.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Terms of Service',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: const [
          _PolicyHeader(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'Last updated: April 2026',
          ),
          SizedBox(height: 24),
          _Section(
            title: '1. Acceptance of Terms',
            content:
                'By downloading, installing, or using TravelBuddy, you agree to be bound by these Terms of Service. '
                'If you do not agree to these terms, please do not use the app.',
          ),
          _Section(
            title: '2. Use of the App',
            content:
                'TravelBuddy is provided for personal, non-commercial use only. You agree to:\n'
                '• Use the app only for lawful purposes.\n'
                '• Not attempt to reverse-engineer, hack, or disrupt the app or its servers.\n'
                '• Not use AI-generated content for misleading or harmful purposes.\n'
                '• Respect the intellectual property of others when uploading photos.',
          ),
          _Section(
            title: '3. User Content',
            content:
                'You retain full ownership of any photos, travel plans, or reels you create using TravelBuddy. '
                'By uploading content, you grant TravelBuddy a limited license to process that content solely for the purpose of providing the app\'s features. '
                'You are responsible for ensuring you have the rights to upload and use any content in the app.',
          ),
          _Section(
            title: '4. AI-Generated Content',
            content:
                'TravelBuddy uses artificial intelligence to generate travel itineraries, stories, and reels. '
                'AI-generated content is for informational and entertainment purposes only. '
                'We do not guarantee the accuracy of AI-generated information, including travel advice, prices, or attraction details. '
                'Always verify important travel information with official sources.',
          ),
          _Section(
            title: '5. Disclaimer of Warranties',
            content:
                'TravelBuddy is provided "as is" without any warranties, express or implied. '
                'We do not warrant that the app will be error-free, uninterrupted, or free of viruses. '
                'We are not responsible for any travel decisions made based on the app\'s AI-generated content.',
          ),
          _Section(
            title: '6. Limitation of Liability',
            content:
                'To the fullest extent permitted by law, TravelBuddy and its developers shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the app, including but not limited to travel disruptions, financial losses, or data loss.',
          ),
          _Section(
            title: '7. Termination',
            content:
                'We reserve the right to suspend or terminate your access to TravelBuddy at any time, without notice, for conduct that we believe violates these Terms of Service or is harmful to other users, us, or third parties.',
          ),
          _Section(
            title: '8. Changes to Terms',
            content:
                'We may modify these Terms of Service at any time. '
                'Changes will be notified through the app\'s update system. '
                'Continued use of TravelBuddy after changes are posted means you accept the new terms.',
          ),
          _Section(
            title: '9. Governing Law',
            content:
                'These Terms of Service are governed by and construed in accordance with applicable laws. '
                'Any disputes arising from these terms shall be resolved through good-faith negotiation.',
          ),
          _Section(
            title: '10. Contact',
            content:
                'For any questions about these Terms of Service, please contact:\n'
                'support@travelbuddy.app',
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _PolicyHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _PolicyHeader({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withAlpha(30)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String content;
  const _Section({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: AppTheme.textPrimary,
            ),
          ),
          const Divider(height: 32, color: AppTheme.borderLight),
        ],
      ),
    );
  }
}
