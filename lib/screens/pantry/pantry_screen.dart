// lib/screens/pantry/pantry_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/pantry_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pantry/item_card.dart';

class PantryScreen extends StatelessWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pantry = context.watch<PantryProvider>();

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        title: Row(
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
      ),
      body: _buildBody(context, pantry),
    );
  }

  Widget _buildBody(BuildContext context, PantryProvider pantry) {
    if (pantry.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.yellow),
      );
    }
    if (pantry.error != null) {
      return Center(
        child: Text(
          'Error: ${pantry.error}',
          style: const TextStyle(color: AppColors.mutedText),
        ),
      );
    }
    if (pantry.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('🥡', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text(
              'No items yet.\nBe the first to share something!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedText, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: pantry.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => ItemCard(item: pantry.items[i]),
    );
  }
}
