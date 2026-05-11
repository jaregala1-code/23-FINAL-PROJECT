// lib/screens/pantry/add_item_screen.dart
//
// Create / edit a surplus item. Adapted to ELBites dark theme.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/surplus_item.dart';
import '../../providers/pantry_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/pantry_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pantry/base64_image.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key, this.existingItem});
  final SurplusItem? existingItem;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  String? _photoBase64;
  DateTime? _expirationDate;
  bool _saving = false;

  bool get _isEdit => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existingItem;
    if (e != null) {
      _titleCtrl.text = e.title;
      _descCtrl.text = e.description;
      _qtyCtrl.text = e.quantity;
      _photoBase64 = e.photoBase64;
      _expirationDate = e.expirationDate;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    final b64 = await PantryService.instance.captureItemPhoto();
    if (b64 != null) setState(() => _photoBase64 = b64);
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? now.add(const Duration(days: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
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
    if (picked != null) setState(() => _expirationDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photoBase64 == null) {
      _snack('Please take a photo of the item.');
      return;
    }
    if (_expirationDate == null) {
      _snack('Please set an expiration date.');
      return;
    }

    setState(() => _saving = true);

    final appUser = context.read<UserProvider>().user;
    if (appUser == null) {
      _snack('You must be logged in to post items.');
      setState(() => _saving = false);
      return;
    }

    final item = SurplusItem(
      id: widget.existingItem?.id,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      quantity: _qtyCtrl.text.trim(),
      expirationDate: _expirationDate!,
      photoBase64: _photoBase64!,
      ownerUid: appUser.uid,
      ownerName: appUser.displayName.isNotEmpty
          ? appUser.displayName
          : appUser.email,
      tags: appUser.foodTagIds,
    );

    final pantry = context.read<PantryProvider>();
    if (_isEdit) {
      await pantry.updateItem(widget.existingItem!.id!, item.toFirestore());
    } else {
      await pantry.postItem(item);
    }

    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          backgroundColor: AppColors.darkBg,
          title: Text(
            _isEdit ? 'Edit Item' : 'Share Surplus Food',
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          iconTheme: const IconThemeData(color: AppColors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo
                _PhotoPicker(base64: _photoBase64, onTap: _capturePhoto),
                const SizedBox(height: 20),

                // Title
                _Label('Item Name'),
                _DarkField(
                  controller: _titleCtrl,
                  hint: 'e.g. 3 extra Eggs',
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter an item name' : null,
                ),
                const SizedBox(height: 16),

                // Quantity
                _Label('Quantity / Amount'),
                _DarkField(
                  controller: _qtyCtrl,
                  hint: 'e.g. Half a bag, 3 pieces',
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter a quantity' : null,
                ),
                const SizedBox(height: 16),

                // Description
                _Label('Description (optional)'),
                _DarkField(
                  controller: _descCtrl,
                  hint: 'Storage tips, pickup notes…',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Expiry
                _Label('Expiration Date'),
                GestureDetector(
                  onTap: _pickExpiry,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 18, color: AppColors.mutedText),
                        const SizedBox(width: 10),
                        Text(
                          _expirationDate != null
                              ? DateFormat('MMMM d, yyyy')
                                  .format(_expirationDate!)
                              : 'Select expiration date',
                          style: TextStyle(
                            color: _expirationDate != null
                                ? AppColors.white
                                : AppColors.mutedText,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.black),
                          )
                        : Text(_isEdit ? 'Update Item' : 'Post Item 🥡'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _DarkField extends StatelessWidget {
  const _DarkField({
    required this.controller,
    this.hint,
    this.validator,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String? hint;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.white, fontSize: 15),
        decoration: InputDecoration(hintText: hint),
        validator: validator,
      );
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.base64, required this.onTap});
  final String? base64;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: base64 != null
              ? Base64Image(
                  base64: base64!,
                  borderRadius: BorderRadius.circular(13),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt,
                        size: 40, color: AppColors.mutedText),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to take a photo',
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                  ],
                ),
        ),
      );
}
