// lib/widgets/profile/location_preference_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/location_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';

class LocationPreferenceWidget extends StatefulWidget {
  const LocationPreferenceWidget({super.key});

  @override
  State<LocationPreferenceWidget> createState() =>
      _LocationPreferenceWidgetState();
}

class _LocationPreferenceWidgetState extends State<LocationPreferenceWidget> {
  late Set<String> _selectedTagIds;
  late bool _notifyNewItems;
  late bool _notifyPickupReminders;
  late bool _notifyChatMessages;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user;
    _selectedTagIds = Set<String>.from(user?.foodTagIds ?? []);
    _notifyNewItems = user?.notifyNewItems ?? true;
    _notifyPickupReminders = user?.notifyPickupReminders ?? true;
    _notifyChatMessages = user?.notifyChatMessages ?? true;
    final uid = user?.uid;
    if (uid != null) {
      context.read<LocationProvider>().loadFromFirestore(uid);
    }
  }

  void _toggleTag(String id) => setState(
    () => _selectedTagIds.contains(id)
        ? _selectedTagIds.remove(id)
        : _selectedTagIds.add(id),
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final locationProvider = context.read<LocationProvider>();
    final userProvider = context.read<UserProvider>();
    final uid = userProvider.user?.uid;
    if (uid == null) {
      setState(() => _saving = false);
      return;
    }

    await locationProvider.saveToFirestore(uid);
    await userProvider.updateUser({
      'foodTagIds': _selectedTagIds.toList(),
      'dietaryTags': _selectedTagIds.toList(),
      'notifyNewItems': _notifyNewItems,
      'notifyPickupReminders': _notifyPickupReminders,
      'notifyChatMessages': _notifyChatMessages,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(const SnackBar(content: Text('Preferences saved!')));
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.location_on_outlined,
          title: 'Your Location',
        ),
        const SizedBox(height: 12),
        _LocationCard(
          address: loc.address,
          detecting: loc.detecting,
          error: loc.error,
          onDetect: () => context.read<LocationProvider>().detectLocation(),
        ),

        const SizedBox(height: 24),

        _SectionHeader(icon: Icons.radar, title: 'Discovery Radius'),
        const SizedBox(height: 4),
        _RadiusSlider(
          value: loc.radiusKm,
          onChanged: (v) => context.read<LocationProvider>().setRadius(v),
        ),

        const SizedBox(height: 24),

        _SectionHeader(
          icon: Icons.restaurant_menu_outlined,
          title: 'Dietary Preferences',
        ),
        const SizedBox(height: 4),
        const Text(
          'Select the food types you want to see in your feed.',
          style: TextStyle(color: AppColors.mutedText, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _FoodTagGrid(
          tags: kFoodTags,
          selectedIds: _selectedTagIds,
          onToggle: _toggleTag,
        ),

        const SizedBox(height: 24),

        _SectionHeader(
          icon: Icons.notifications_active_outlined,
          title: 'Notifications',
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose which alerts you want to receive.',
          style: TextStyle(color: AppColors.mutedText, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _NotificationToggle(
          label: 'New items matching your tags',
          subtitle: 'Get pinged when a neighbour posts food you might like.',
          value: _notifyNewItems,
          onChanged: (v) => setState(() => _notifyNewItems = v),
        ),
        _NotificationToggle(
          label: 'Pickup reminders',
          subtitle: 'A nudge 1 hour before an agreed meetup.',
          value: _notifyPickupReminders,
          onChanged: (v) => setState(() => _notifyPickupReminders = v),
        ),
        _NotificationToggle(
          label: 'Chat messages',
          subtitle: 'New messages from givers and receivers.',
          value: _notifyChatMessages,
          onChanged: (v) => setState(() => _notifyChatMessages = v),
        ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.black,
                    ),
                  )
                : const Text('Save Preferences'),
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.yellow),
      const SizedBox(width: 6),
      Text(
        title,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.address,
    required this.detecting,
    required this.onDetect,
    this.error,
  });
  final String address;
  final bool detecting;
  final String? error;
  final VoidCallback onDetect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                address,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            detecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.yellow,
                    ),
                  )
                : TextButton.icon(
                    onPressed: onDetect,
                    icon: const Icon(
                      Icons.my_location,
                      size: 16,
                      color: AppColors.yellow,
                    ),
                    label: const Text(
                      'Detect',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.yellow,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                  ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: const TextStyle(color: Color(0xFFcf6679), fontSize: 11),
          ),
        ],
      ],
    ),
  );
}

class _RadiusSlider extends StatelessWidget {
  const _RadiusSlider({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = value == 0
        ? 'Current location only'
        : '${value.toStringAsFixed(1)} km radius';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.yellow,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Text(
              '0 – 5 km',
              style: TextStyle(color: AppColors.mutedText, fontSize: 11),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.yellow,
            thumbColor: AppColors.yellow,
            inactiveTrackColor: AppColors.border,
            overlayColor: AppColors.yellow.withValues(alpha: 0.12),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 5,
            divisions: 10,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['0', '1', '2', '3', '4', '5']
                .map(
                  (t) => Text(
                    t,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 10,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _NotificationToggle extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationToggle({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        dense: true,
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.yellow,
        title: Text(
          label,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
        ),
      ),
    );
  }
}

class _FoodTagGrid extends StatelessWidget {
  const _FoodTagGrid({
    required this.tags,
    required this.selectedIds,
    required this.onToggle,
  });
  final List<DietaryTag> tags;
  final Set<String> selectedIds;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: tags.map((tag) {
      final selected = selectedIds.contains(tag.id);
      return GestureDetector(
        onTap: () => onToggle(tag.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.yellow : AppColors.cardBg2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.yellow : AppColors.border,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tag.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                tag.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppColors.black : AppColors.white,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.check_circle,
                  size: 14,
                  color: AppColors.black,
                ),
              ],
            ],
          ),
        ),
      );
    }).toList(),
  );
}
