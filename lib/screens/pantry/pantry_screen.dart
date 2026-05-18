// lib/screens/pantry/pantry_screen.dart
//
// Bumble-style swipe card feed. Uses existing PantryProvider + SurplusItem.
// Swipe right → claim request. Swipe left → pass. Tap → detail sheet.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  // final int _topIndex = 0;
  // Track items already swiped so reloads don't re-show them
  final Set<String> _dismissed = {};

  // Drag state for swipe overlay
  double _dragX = 0;
  bool _isDragging = false;

  late AnimationController _flyCtrl;
  late Animation<Offset> _flyAnim;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _flyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flyAnim = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _flyCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _flyCtrl.dispose();
    super.dispose();
  }

  List<SurplusItem> _visible(List<SurplusItem> all) =>
      all.where((i) => !_dismissed.contains(i.id)).toList();

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
    _sendClaimRequest(item);
  }

  Future<void> _swipeLeft(SurplusItem item) async {
    if (_isAnimating) return;
    await _animateOff(false);
    _dismissed.add(item.id!);
    setState(() {});
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
      requesterName:
          me.displayName.isNotEmpty ? me.displayName : me.email,
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
          backgroundColor:
              success ? AppColors.green : AppColors.error,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
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

          // Filter out own items and already-dismissed
          final myUidSafe = myUid;
          final items = pantry.items
              .where((i) =>
                  i.ownerUid != myUidSafe &&
                  i.status == ItemStatus.available &&
                  !_dismissed.contains(i.id))
              .toList();

          if (items.isEmpty) {
            return const _EmptyState(
              emoji: '🍽️',
              message: 'No food nearby right now',
              sub: 'Check back soon — the Elbi community posts new items all the time.',
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
                    child: SwipeCard(
                      item: items[1],
                      dragX: 0,
                      isBack: true,
                    ),
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
                    setState(() {
                      _isDragging = true;
                      _dragX += d.delta.dx;
                    });
                  },
                  onHorizontalDragEnd: (d) {
                    if (_isAnimating) return;
                    final velocity = d.primaryVelocity ?? 0;
                    if (_dragX > 80 || velocity > 400) {
                      _swipeRight(items[0]);
                    } else if (_dragX < -80 || velocity < -400) {
                      _swipeLeft(items[0]);
                    } else {
                      setState(() {
                        _dragX = 0;
                        _isDragging = false;
                      });
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _flyCtrl,
                    builder: (_, child) {
                      final offset = _isAnimating
                          ? _flyAnim.value
                          : Offset(_dragX / MediaQuery.of(context).size.width, 0);
                      final angle = offset.dx * 0.3;
                      return Transform.translate(
                        offset: Offset(
                          offset.dx * MediaQuery.of(context).size.width,
                          0,
                        ),
                        child: Transform.rotate(
                          angle: angle,
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
            child: const Center(child: Text('🥡', style: TextStyle(fontSize: 14))),
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
    // Simple tag filter — can be expanded
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
