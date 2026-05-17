import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/dietary_tag.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_text_field.dart';
import '../widgets/dietary_tag_chip.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  // State
  List<String> _selectedTags = [];
  DateTime? _availableFrom;
  DateTime? _availableUntil;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Date / time helpers ──

  Future<void> _pickDateTime({required bool isFrom}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (_availableFrom ?? now)
          : (_availableUntil ?? (_availableFrom ?? now)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 30)),
      builder: (ctx, child) => _datepickerTheme(ctx, child),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => _datepickerTheme(ctx, child),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isFrom) {
        _availableFrom = dt;
        // Reset until if it's now earlier than from
        if (_availableUntil != null && _availableUntil!.isBefore(dt)) {
          _availableUntil = null;
        }
      } else {
        _availableUntil = dt;
      }
    });
  }

  Widget _datepickerTheme(BuildContext ctx, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.yellow,
          onPrimary: AppColors.black,
          surface: AppColors.cardBg,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.yellow),
        ),
      ),
      child: child!,
    );
  }

  // ── Submit ──

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_availableFrom == null) {
      _showSnack('Please set an availability start date/time.');
      return;
    }

    setState(() => _isSubmitting = true);

    final uid = context.read<UserAuthProvider>().appUser?.uid ?? '';
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final items = FirebaseFirestore.instance.collection('items');
    // Generate the ref up-front so we can write the id into the doc.
    final docRef = items.doc();

    final postData = {
      'id': docRef.id,
      'ownerUid': uid,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'quantity': _quantityController.text.trim(),
      'location': _locationController.text.trim(),
      'notes': _notesController.text.trim(),
      'dietaryTags': _selectedTags,
      'availableFrom': Timestamp.fromDate(_availableFrom!),
      'availableUntil': _availableUntil != null
          ? Timestamp.fromDate(_availableUntil!)
          : null,
      'status': 'available',
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Fire-and-forget the server commit: Firestore's local cache fires
    // snapshot listeners immediately, so feeds update without waiting on
    // the network roundtrip (and the spinner doesn't hang post-write).
    docRef.set(postData).catchError((e) {
      debugPrint('[CreatePost] write error: $e');
    });

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    messenger.showSnackBar(
      SnackBar(
        content: const Text(
          '🎉 Your post is live!',
          style: TextStyle(color: AppColors.black, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.yellow,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      _resetForm();
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _descriptionController.clear();
    _quantityController.clear();
    _locationController.clear();
    _notesController.clear();
    setState(() {
      _selectedTags = [];
      _availableFrom = null;
      _availableUntil = null;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.yellow,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        title: const Text('Share Food'),
        centerTitle: false,
        actions: [
          if (_isSubmitting)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.yellow,
                  ),
                ),
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
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            // ── Food Details ──
            _SectionLabel(label: 'Food Details', emoji: '🍱'),
            const SizedBox(height: 12),

            AppTextField(
              controller: _titleController,
              label: 'Food / Item Name',
              hint: 'e.g. Leftover Kare-kare',
              prefixIcon: Icons.restaurant_menu_outlined,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter the food name'
                  : null,
            ),
            const SizedBox(height: 14),

            AppTextField(
              controller: _descriptionController,
              label: 'Description',
              hint:
                  'Describe the food — ingredients, how it was prepared, etc.',
              prefixIcon: Icons.notes_outlined,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please add a description'
                  : null,
            ),
            const SizedBox(height: 14),

            AppTextField(
              controller: _quantityController,
              label: 'Quantity / Servings',
              hint: 'e.g. 3 servings, 500g, half loaf',
              prefixIcon: Icons.scale_outlined,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter the quantity'
                  : null,
            ),

            const SizedBox(height: 24),

            // ── Pickup Details ──
            _SectionLabel(label: 'Pickup Details', emoji: '📍'),
            const SizedBox(height: 12),

            AppTextField(
              controller: _locationController,
              label: 'Pickup Location',
              hint: 'e.g. Katipunan Ave, near 7-Eleven',
              prefixIcon: Icons.location_on_outlined,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter the pickup location'
                  : null,
            ),
            const SizedBox(height: 14),

            // Available From
            _DateTimeTile(
              label: 'Available From',
              icon: Icons.calendar_today_outlined,
              value: _availableFrom,
              onTap: () => _pickDateTime(isFrom: true),
              required: true,
            ),
            const SizedBox(height: 10),

            // Available Until (optional)
            _DateTimeTile(
              label: 'Available Until (optional)',
              icon: Icons.event_outlined,
              value: _availableUntil,
              onTap: () => _pickDateTime(isFrom: false),
              required: false,
            ),

            const SizedBox(height: 24),

            // ── Dietary Tags ──
            _SectionLabel(label: 'Dietary Tags', emoji: '🏷️'),
            const SizedBox(height: 4),
            const Text(
              'Select all that apply',
              style: TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppTags.dietary.map((tag) {
                final isSelected = _selectedTags.contains(tag.id);
                return DietaryTagChip(
                  tag: tag,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedTags.remove(tag.id);
                      } else {
                        _selectedTags.add(tag.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ── Additional Notes ──
            _SectionLabel(label: 'Additional Notes', emoji: '📝'),
            const SizedBox(height: 12),

            AppTextField(
              controller: _notesController,
              label: 'Notes (optional)',
              hint: 'Allergen warnings, storage tips, contact preferences...',
              prefixIcon: Icons.info_outline_rounded,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 32),

            // ── Submit Button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.black,
                        ),
                      )
                    : const Text('Share This Food 🥡'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable sub-widgets ──

class _SectionLabel extends StatelessWidget {
  final String label;
  final String emoji;
  const _SectionLabel({required this.label, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime? value;
  final VoidCallback onTap;
  final bool required;

  const _DateTimeTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    required this.required,
  });

  String _formatDt(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  ·  $h:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: required && value == null
                ? AppColors.border
                : (value != null
                      ? AppColors.green.withValues(alpha: 0.5)
                      : AppColors.border),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.mutedText),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value != null ? _formatDt(value!) : label,
                style: TextStyle(
                  color: value != null ? AppColors.white : AppColors.mutedText,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.mutedText,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
