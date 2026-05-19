// lib/screens/pantry/pantry_screen.dart
//
// Bumble-style swipe card feed.
// _dismissed is persisted to Firestore (users/{uid}/dismissedItems)
// so swiped items do not reappear after logout/login.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/surplus_item.dart';
import '../../providers/pantry_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/claim_service.dart';
import '../../widgets/pantry/swipe_card.dart';
import 'food_detail_sheet.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen>
    with SingleTickerProviderStateMixin {
  // Persisted across sessions via Firestore
  final Set<String> _dismissed = {};
  bool _dismissedLoaded = false;

  // Drag / animation state
  double _dragX = 0;
  late AnimationController _flyCtrl;
  late Animation<Offset> _flyAnim;
  bool _isAnimating = false;

  // ── Firestore helpers ───────────────────────────────────────────────────────

  String? _myUid() {
    final auth = context.read<UserAuthProvider>();
    final user = context.read<UserProvider>();
    return auth.appUser?.uid ?? user.user?.uid;
  }

  /// Load dismissed item IDs from Firestore when screen first opens.
  Future<void> _loadDismissed() async {
    final uid = _myUid();
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data != null && data['dismissedItems'] is List) {
        final ids = List<String>.from(data['dismissedItems'] as List);
        if (mounted) {
          setState(() {
            _dismissed.addAll(ids);
            _dismissedLoaded = true;
          });
        }
      } else {
        if (mounted) setState(() => _dismissedLoaded = true);
      }
    } catch (_) {
      // Fail silently — worst case items reappear once
      if (mounted) setState(() => _dismissedLoaded = true);
    }
  }

  /// Persist a newly dismissed item ID to Firestore using arrayUnion.
  Future<void> _persistDismissed(String itemId) async {
    final uid = _myUid();
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'dismissedItems': FieldValue.arrayUnion([itemId]),
      });
    } catch (_) {
      // Non-critical — local set already updated
    }
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _flyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flyAnim = const AlwaysStoppedAnimation(Offset.zero);

    // Load persisted dismissed IDs after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDismissed());
  }

  @override
  void dispose() {
    _flyCtrl.dispose();
    super.dispose();
  }

  // ── Swipe logic ─────────────────────────────────────────────────────────────

  Future<void> _animateOff(bool toRight) async {
    setState(() => _isAnimating = true);
    _flyAnim = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(toRight ? 1.5 : -1.5, 0),
    ).animate(CurvedAnimation(parent: _flyCtrl, curve: Curves.easeOut));
    _flyCtrl.reset();
    await _flyCtrl.forward();
    setState(() {
      _isAnimating = false;
      _dragX = 0;
    });
  }

  Future<void> _swipeRight(SurplusItem item) async {
    if (_isAnimating) return;
    await _animateOff(true);
    _dismissed.add(item.id!);
    setState(() {});
    _persistDismissed(item.id!); // ← write to Firestore
    _sendClaimRequest(item);
  }

  Future<void> _swipeLeft(SurplusItem item) async {
    if (_isAnimating) return;
    await _animateOff(false);
    _dismissed.add(item.id!);
    setState(() {});
    _persistDismissed(item.id!); // ← write to Firestore
  }

  void _sendClaimRequest(SurplusItem item) async {
    final authProvider = context.read<UserAuthProvider>();
    final userProvider = context.read<UserProvider>();
    final me = authProvider.appUser ?? userProvider.user;
    if (me == null || item.id == null) return;

    final success = await ClaimService.instance.requestItem(
      itemId: item.id!,
      itemTitle: item.title,
      ownerUid: item.ownerUid,
      ownerName: item.ownerName,
      requesterUid: me.uid,
      requesterName: me.displayName.isNotEmpty ? me.displayName : me.email,
      requesterPhotoBase64: me.profileImageBase64,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '🛒 Added to your Tray!'
                : 'Could not send request. Try again.',
          ),
          backgroundColor: success ? AppColors.green : AppColors.error,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openDetail(SurplusItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodDetailSheet(
        item: item,
        onAddToTray: () {
          Navigator.pop(context);
          _swipeRight(item);
        },
        onPass: () {
          Navigator.pop(context);
          _swipeLeft(item);
        },
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();
    final authProvider = context.watch<UserAuthProvider>();
    final myUid = authProvider.appUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: _buildAppBar(context),
      body: Builder(
        builder: (_) {
          // Show spinner until dismissed list is loaded from Firestore
          if (!_dismissedLoaded) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            );
          }
          if (pantry.loading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.yellow),
            );
          }
          if (pantry.error != null) {
            return _EmptyState(
              emoji: '⚠️',
              message: 'Error loading pantry',
              sub: pantry.error!,
            );
          }

          final items = pantry.items
              .where(
                (i) =>
                    i.ownerUid != myUid &&
                    i.status == ItemStatus.available &&
                    !_dismissed.contains(i.id),
              )
              .toList();

          if (items.isEmpty) {
            return const _EmptyState(
              emoji: '🍽️',
              message: 'No food nearby right now',
              sub:
                  'Check back soon — the Elbi community posts new items all the time.',
            );
          }

          return Stack(
            children: [
              // Background peek card
              if (items.length > 1)
                Positioned(
                  top: 24,
                  left: 28,
                  right: 28,
                  bottom: 108,
                  child: Transform.scale(
                    scale: 0.94,
                    child: SwipeCard(item: items[1], dragX: 0, isBack: true),
                  ),
                ),

              // Top card — draggable
              Positioned(
                top: 8,
                left: 16,
                right: 16,
                bottom: 100,
                child: GestureDetector(
                  onTap: () => _openDetail(items[0]),
                  onHorizontalDragUpdate: (d) {
                    if (_isAnimating) return;
                    setState(() => _dragX += d.delta.dx);
                  },
                  onHorizontalDragEnd: (d) {
                    if (_isAnimating) return;
                    final velocity = d.primaryVelocity ?? 0;
                    if (_dragX > 80 || velocity > 400) {
                      _swipeRight(items[0]);
                    } else if (_dragX < -80 || velocity < -400) {
                      _swipeLeft(items[0]);
                    } else {
                      setState(() => _dragX = 0);
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _flyCtrl,
                    builder: (_, child) {
                      final offset = _isAnimating
                          ? _flyAnim.value
                          : Offset(
                              _dragX / MediaQuery.of(context).size.width,
                              0,
                            );
                      return Transform.translate(
                        offset: Offset(
                          offset.dx * MediaQuery.of(context).size.width,
                          0,
                        ),
                        child: Transform.rotate(
                          angle: offset.dx * 0.3,
                          child: child,
                        ),
                      );
                    },
                    child: SwipeCard(
                      item: items[0],
                      dragX: _dragX,
                      isBack: false,
                    ),
                  ),
                ),
              ),

              // Action buttons
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: _ActionButtons(
                  onPass: () => _swipeLeft(items[0]),
                  onInfo: () => _openDetail(items[0]),
                  onTray: () => _swipeRight(items[0]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.darkBg,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('🥡', style: TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'The Pantry',
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.tune_outlined, color: AppColors.white),
          tooltip: 'Filter',
          onPressed: () => _showFilterSheet(context),
        ),
      ],
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Pantry',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your dietary tags already filter your feed. '
              'Tap any item card for full details.',
              style: TextStyle(color: AppColors.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Action buttons row ────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final VoidCallback onPass;
  final VoidCallback onInfo;
  final VoidCallback onTray;

  const _ActionButtons({
    required this.onPass,
    required this.onInfo,
    required this.onTray,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CircleBtn(
          icon: Icons.close_rounded,
          color: AppColors.error,
          size: 56,
          onTap: onPass,
        ),
        const SizedBox(width: 16),
        _CircleBtn(
          icon: Icons.info_outline_rounded,
          color: AppColors.mutedText,
          size: 44,
          onTap: onInfo,
        ),
        const SizedBox(width: 16),
        _CircleBtn(
          icon: Icons.shopping_basket_outlined,
          color: AppColors.green,
          size: 56,
          onTap: onTray,
        ),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _CircleBtn({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.cardBg,
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.42),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String emoji;
  final String message;
  final String sub;

  const _EmptyState({
    required this.emoji,
    required this.message,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              sub,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
