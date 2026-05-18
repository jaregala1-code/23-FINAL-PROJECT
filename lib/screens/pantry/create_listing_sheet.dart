// lib/screens/pantry/create_listing_sheet.dart
//
// Modal bottom sheet for creating a new surplus item.
// Camera-only photo (spec requirement).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/surplus_item.dart';
import '../../providers/pantry_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/pantry_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pantry/base64_image.dart';

class CreateListingSheet extends StatefulWidget {
  const CreateListingSheet({super.key});

  @override
  State<CreateListingSheet> createState() => _CreateListingSheetState();
}

class _CreateListingSheetState extends State<CreateListingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  String? _photoBase64;
  DateTime? _expirationDate;
  final List<String> _selectedTags = [];
  bool _saving = false;

  // All available tags (from existing app_user.dart kFoodTags)
  static const _tags = [
    ('🌱', 'Vegan'),
    ('🥦', 'Vegetarian'),
    ('☪️', 'Halal'),
    ('🌾', 'Gluten-Free'),
    ('🥛', 'Dairy-Free'),
    ('🍳', 'Home-Cooked'),
    ('🥕', 'Raw Ingredients'),
    ('🍚', 'Rice Meals'),
    ('🥑', 'Keto'),
    ('🍎', 'Fresh Fruits'),
    ('🥖', 'Bakery & Bread'),
    ('🫙', 'Pantry Staples'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final b64 = await PantryService.instance.captureItemPhoto();
    if (b64 != null) setState(() => _photoBase64 = b64);
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? now.add(const Duration(hours: 8)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.yellow,
            onPrimary: AppColors.black,
            surface: AppColors.cardBg,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _expirationDate ?? now.add(const Duration(hours: 8)),
      ),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.yellow,
            onPrimary: AppColors.black,
            surface: AppColors.cardBg,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _expirationDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photoBase64 == null) {
      _snack('Please take a photo of your item.');
      return;
    }
    if (_expirationDate == null) {
      _snack('Please set an expiration date.');
      return;
    }

    setState(() => _saving = true);

    final authProvider = context.read<UserAuthProvider>();
    final userProvider = context.read<UserProvider>();
    final me = authProvider.appUser ?? userProvider.user;

    if (me == null) {
      _snack('Please sign in first.');
      setState(() => _saving = false);
      return;
    }

    // Snap the giver's saved location onto the listing so the Cloud
    // Function can filter "interested users within radius".
    final loc = context.read<LocationProvider>();
    final GeoPoint? pickupGeo = (loc.latitude != null && loc.longitude != null)
        ? GeoPoint(loc.latitude!, loc.longitude!)
        : me.location;

    final item = SurplusItem(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      quantity: _qtyCtrl.text.trim(),
      expirationDate: _expirationDate!,
      photoBase64: _photoBase64!,
      ownerUid: me.uid,
      ownerName: me.displayName.isNotEmpty ? me.displayName : me.email,
      tags: List<String>.from(_selectedTags),
      location: pickupGeo,
      locationAddress: loc.hasLocation ? loc.address : me.locationAddress,
    );

    // Capture messenger & navigator before async gap so we don't look
    // them up on a deactivated element after Navigator.pop().
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final newId = await context.read<PantryProvider>().postItem(item);
    if (!mounted) return;
    setState(() => _saving = false);

    if (newId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not post your item. Please try again.'),
          backgroundColor: AppColors.error,
          margin: EdgeInsets.all(16),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('🎉 Your item is now live in the Pantry!'),
        backgroundColor: AppColors.green,
        margin: EdgeInsets.all(16),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Text(
                  'Share Food',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (_saving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.yellow,
                    ),
                  )
                else
                  TextButton(
                    onPressed: _submit,
                    child: const Text(
                      'Post',
                      style: TextStyle(
                        color: AppColors.yellow,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo
                    GestureDetector(
                      onTap: _takePhoto,
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.cardBg2,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: _photoBase64 != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Base64Image(
                                  base64: _photoBase64!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.camera_alt_outlined,
                                    size: 40,
                                    color: AppColors.mutedText,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Tap to take a photo',
                                    style: TextStyle(
                                      color: AppColors.mutedText,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Camera only — no gallery uploads',
                                    style: TextStyle(
                                      color: AppColors.mutedText,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    _DarkField(
                      controller: _titleCtrl,
                      label: 'Item Name *',
                      hint: 'e.g. "3 extra eggs", "Half a bag of rice"',
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Quantity
                    _DarkField(
                      controller: _qtyCtrl,
                      label: 'Quantity *',
                      hint: 'e.g. "3 pieces", "1 pack", "500g"',
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Description
                    _DarkField(
                      controller: _descCtrl,
                      label: 'Description',
                      hint: 'Storage tips, allergy info, how it was prepared…',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),

                    // Expiry
                    GestureDetector(
                      onTap: _pickExpiry,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.inputBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: AppColors.mutedText,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _expirationDate != null
                                  ? 'Expires ${DateFormat('MMM d, y – h:mm a').format(_expirationDate!)}'
                                  : 'Best-before date * (tap to set)',
                              style: TextStyle(
                                color: _expirationDate != null
                                    ? AppColors.white
                                    : AppColors.mutedText,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tags
                    const Text(
                      'Dietary Tags',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tags.map((t) {
                        final isSelected = _selectedTags.contains(t.$2);
                        return GestureDetector(
                          onTap: () => _toggleTag(t.$2),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.yellow
                                  : AppColors.cardBg2,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.yellow
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  t.$1,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  t.$2,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.black
                                        : AppColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final int maxLines;

  const _DarkField({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.white, fontSize: 14),
          decoration: InputDecoration(hintText: hint),
          validator: validator,
        ),
      ],
    );
  }
}
