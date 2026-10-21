import 'package:flutter/material.dart';

const Color kTealColor = Color(0xFF26A69A);

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  int? _expandedIndex;
  String _selectedCategory = 'All';

  final List<Map<String, String>> _faqs = [
    {
      'question': 'What is Circl Points?',
      'answer':
          'Circl Points are rewards you earn by completing requests, posting items, or helping others. Accumulate points to unlock higher Aura levels and enjoy exclusive benefits.',
      'category': 'Getting Started',
    },
    {
      'question': 'How do I increase my Aura Level?',
      'answer':
          'Your Aura Level increases as you earn more Circl Points through active participation. Complete requests, maintain high ratings, and engage with the community to climb from Bronze → Silver → Gold → Platinum.',
      'category': 'Getting Started',
    },
    {
      'question': 'What are the benefits of higher Aura Levels?',
      'answer':
          'Higher Aura Levels unlock: Priority in request matching, increased borrowing limits, trust badges on your profile, and access to exclusive Circl events and opportunities.',
      'category': 'Getting Started',
    },
    {
      'question': 'How does the wallet system work?',
      'answer':
          'Your wallet holds funds from paid requests and rentals. You can add money via card or bank transfer, and withdraw earnings. A small platform fee applies to transactions.',
      'category': 'Payments',
    },
    {
      'question': 'Is my location data shared with others?',
      'answer':
          'Your exact location is only visible to users you accept requests from. General location (city/area) appears on your profile. You control your privacy settings at any time.',
      'category': 'Safety',
    },
    {
      'question': 'How are disputes resolved?',
      'answer':
          'If there\'s a disagreement, both parties can open a dispute in the Dispute Center. Our team reviews evidence and makes a fair decision within 48 hours.',
      'category': 'Safety',
    },
    {
      'question': 'Can I cancel a request?',
      'answer':
          'Yes, you can cancel pending requests free of charge. If a request is already accepted, cancellation may incur a small fee to protect other users.',
      'category': 'Requests',
    },
    {
      'question': 'How do reviews work?',
      'answer':
          'After completing a request, both users rate each other 1-5 stars and can leave comments. Reviews are public and help build trust in the community.',
      'category': 'Requests',
    },
    {
      'question': 'What if someone violates community guidelines?',
      'answer':
          'You can report concerning behavior via the Report button. Our moderation team investigates and takes appropriate action, which may include warnings or account suspension.',
      'category': 'Safety',
    },
    {
      'question': 'How do I delete my account?',
      'answer':
          'Go to Settings → Account → Delete Account. Your data will be deleted within 30 days, but your public reviews will remain attributed anonymously.',
      'category': 'Getting Started',
    },
  ];

  List<Map<String, String>> get _filteredFaqs {
    if (_selectedCategory == 'All') {
      return _faqs;
    }
    return _faqs.where((faq) => faq['category'] == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface;

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
          'FAQ & Help',
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(isDark, textColor),
            const SizedBox(height: 20),
            const Text(
              'Popular Topics',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildPillFilterChip('All', isDark),
                  const SizedBox(width: 8),
                  _buildPillFilterChip('Getting Started', isDark),
                  const SizedBox(width: 8),
                  _buildPillFilterChip('Requests', isDark),
                  const SizedBox(width: 8),
                  _buildPillFilterChip('Payments', isDark),
                  const SizedBox(width: 8),
                  _buildPillFilterChip('Safety', isDark),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'All Questions',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredFaqs.length,
              itemBuilder: (context, index) {
                final faq = _filteredFaqs[index];
                final isExpanded = _expandedIndex == index;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isExpanded
                          ? kTealColor
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isExpanded ? 2 : 1,
                    ),
                    boxShadow: isExpanded
                        ? [
                            BoxShadow(
                              color: kTealColor.withValues(alpha: 0.1),
                              blurRadius: 8,
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        title: Text(
                          faq['question']!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isExpanded
                                ? kTealColor
                                : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                        trailing: AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.expand_more,
                            color: isExpanded
                                ? kTealColor
                                : (isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)),
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _expandedIndex = isExpanded ? null : index;
                          });
                        },
                      ),
                      if (isExpanded)
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: 16),
                              Text(
                                faq['answer']!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    kTealColor.withValues(alpha: 0.1),
                    const Color(0xFF0F766E).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: kTealColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kTealColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.headset_mic,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Need More Help?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Our support team is here to help! Reach out to us via email or chat.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Support chat coming soon!'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('Contact Support'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTealColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
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

  Widget _buildSearchBar(bool isDark, Color textColor) {
    final searchBarColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final iconColor = isDark ? Colors.grey.shade500 : Colors.blueGrey;
    final hintColor = isDark ? Colors.grey.shade500 : Colors.grey.shade400;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: searchBarColor,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 16),
          Icon(
            Icons.search_rounded,
            color: iconColor,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(fontSize: 13, color: textColor),
              onChanged: (value) {
              },
              decoration: InputDecoration(
                hintText: 'Search FAQs...',
                hintStyle: TextStyle(color: hintColor, fontSize: 13),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildPillFilterChip(String label, bool isDark) {
    final isSelected = _selectedCategory == label;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? kTealColor 
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected 
                ? kTealColor 
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: kTealColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 0.2,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected 
                ? Colors.white 
                : (isDark ? Colors.grey.shade400 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}