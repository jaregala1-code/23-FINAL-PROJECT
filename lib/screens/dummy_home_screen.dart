import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';

class DummyHomeScreen extends StatelessWidget {
  const DummyHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appUser = context.watch<UserAuthProvider>().appUser;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.darkBg,
            title: Row(
              children: [
                // Logo mark
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'E',
                      style: TextStyle(
                        color: AppColors.darkBg,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'ELBites',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.white,
                ),
                onPressed: () {
                  // TODO: Navigate to notifications screen
                },
              ),
            ],
          ),

          // ── Body ──
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Greeting banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1a2e14), Color(0xFF1e1e1e)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, ${appUser?.firstName ?? 'neighbor'} 👋',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'What would you like to share today?',
                              style: TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('🥡', style: TextStyle(fontSize: 36)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Section label
                const Text(
                  'Available Near You',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Placeholder — real listings will appear here once\nfood posts are connected to Firestore.',
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Dummy food cards
                ..._dummyPosts.map((post) => _FoodCard(post: post)),

                const SizedBox(height: 24),

                // Category quick-filters
                const Text(
                  'Browse by Tag',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tagChips
                      .map((t) => _TagPill(emoji: t.$1, label: t.$2))
                      .toList(),
                ),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dummy data ──

const _dummyPosts = [
  _DummyPost(
    emoji: '🍱',
    title: 'Leftover Kare-kare',
    owner: 'Maria Santos',
    location: 'UP Diliman, Krus na Ligas Gate',
    servings: '3 servings',
    tag: 'Home-Cooked',
    tagColor: AppColors.green,
    timeAgo: '12 min ago',
  ),
  _DummyPost(
    emoji: '🥖',
    title: 'Sourdough Loaf (half)',
    owner: 'Juan dela Cruz',
    location: 'Katipunan Ave, near 7-Eleven',
    servings: 'Half loaf',
    tag: 'Vegan',
    tagColor: Color(0xFF4d8b31),
    timeAgo: '35 min ago',
  ),
  _DummyPost(
    emoji: '🍛',
    title: 'Extra Adobo Rice',
    owner: 'Ana Reyes',
    location: 'Maginhawa St, Teacher\'s Village',
    servings: '2 cups',
    tag: 'Halal',
    tagColor: AppColors.orange,
    timeAgo: '1 hr ago',
  ),
];

const _tagChips = [
  ('🌱', 'Vegan'),
  ('☪️', 'Halal'),
  ('🍳', 'Home-Cooked'),
  ('🥦', 'Vegetarian'),
  ('🌾', 'Gluten-Free'),
  ('🥕', 'Raw Ingredients'),
  ('🥑', 'Keto'),
  ('🍎', 'Fresh Fruits'),
];

class _DummyPost {
  final String emoji;
  final String title;
  final String owner;
  final String location;
  final String servings;
  final String tag;
  final Color tagColor;
  final String timeAgo;

  const _DummyPost({
    required this.emoji,
    required this.title,
    required this.owner,
    required this.location,
    required this.servings,
    required this.tag,
    required this.tagColor,
    required this.timeAgo,
  });
}

// ── Sub-widgets ──

class _FoodCard extends StatelessWidget {
  final _DummyPost post;
  const _FoodCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Food emoji box
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.cardBg2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(post.emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        post.title,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: post.tagColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        post.tag,
                        style: TextStyle(
                          color: post.tagColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${post.owner} · ${post.servings}',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: AppColors.mutedText,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        post.location,
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      post.timeAgo,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String emoji;
  final String label;
  const _TagPill({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
