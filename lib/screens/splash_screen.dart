import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/elbites_logo.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // Logo + tagline
                  const ElbitesLogo(size: 72),
                  const SizedBox(height: 20),
                  Text(
                    'Share what you have.\nNourish your community.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.white.withOpacity(0.55),
                      fontSize: 16,
                      height: 1.55,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const Spacer(flex: 3),
                  // Illustration placeholder — three stacked cards
                  _IllustrationStack(),
                  const Spacer(flex: 2),
                  // CTA buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      ),
                      child: const Text('Create an Account'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.white,
                        side: const BorderSide(
                          color: AppColors.border,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      child: const Text('Sign In'),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IllustrationStack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cards = [
      ('🥚', 'Fresh Eggs', '3 available • 0.2 km'),
      ('🍅', 'Garden Tomatoes', '6 pieces • 0.5 km'),
      ('🍞', 'Homemade Bread', '1 loaf • 0.8 km'),
    ];

    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // back card
          Positioned(
            top: 0,
            child: Transform.rotate(
              angle: -0.08,
              child: _MiniCard(
                emoji: cards[2].$1,
                title: cards[2].$2,
                subtitle: cards[2].$3,
                opacity: 0.45,
              ),
            ),
          ),
          // mid card
          Positioned(
            top: 16,
            child: Transform.rotate(
              angle: 0.04,
              child: _MiniCard(
                emoji: cards[1].$1,
                title: cards[1].$2,
                subtitle: cards[1].$3,
                opacity: 0.72,
              ),
            ),
          ),
          // front card
          Positioned(
            top: 32,
            child: _MiniCard(
              emoji: cards[0].$1,
              title: cards[0].$2,
              subtitle: cards[0].$3,
              opacity: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final double opacity;

  const _MiniCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.green.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Free',
                style: TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
