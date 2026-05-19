// lib/screens/chat/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/chat_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/claim_service.dart';
import '../../theme/app_theme.dart';
import '../qr/qr_display_screen.dart';

class ChatScreen extends StatefulWidget {
  final Chat chat;
  final String myUid;

  const ChatScreen({super.key, required this.chat, required this.myUid});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<UserAuthProvider>();
    final userProvider = context.read<UserProvider>();
    final me = authProvider.appUser ?? userProvider.user;
    if (me == null) return;

    final myName = me.displayName.isNotEmpty ? me.displayName : me.email;

    await chatProvider.sendMessage(
      chatId: widget.chat.id,
      senderId: widget.myUid,
      senderName: myName,
      text: text,
    );

    await Future.delayed(const Duration(milliseconds: 80));
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickMeetupTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
      builder: (ctx, child) => _datepickerTheme(ctx, child),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
      builder: (ctx, child) => _datepickerTheme(ctx, child),
    );
    if (time == null || !mounted) return;
    final meetupTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    final itemId = widget.chat.relatedItemId;
    final itemTitle = widget.chat.relatedItemTitle ?? 'item';
    if (itemId == null) {
      _snack('No item is linked to this chat.');
      return;
    }

    final authProvider = context.read<UserAuthProvider>();
    final userProvider = context.read<UserProvider>();
    final chatProvider = context.read<ChatProvider>();
    final me = authProvider.appUser ?? userProvider.user;
    if (me == null) return;
    final myName = me.displayName.isNotEmpty ? me.displayName : me.email;
    final otherName = widget.chat.getOtherName(widget.myUid);
    final receiverUid = widget.chat.getOtherUid(widget.myUid);

    final dynamic claimService = ClaimService.instance;
    final ok = await claimService.setAgreedPickupTime(
      itemId: itemId,
      itemTitle: itemTitle,
      requesterUid: receiverUid,
      otherPartyName: otherName,
      meetupTime: meetupTime,
    );

    if (!mounted) return;
    if (!ok) {
      _snack('Could not save the pickup time. Try again.');
      return;
    }

    await chatProvider.sendMessage(
      chatId: widget.chat.id,
      senderId: widget.myUid,
      senderName: myName,
      text:
          'Pickup set for ${DateFormat('EEE MMM d, h:mm a').format(meetupTime)}',
      type: ChatMessageType.system,
    );
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

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final otherName = widget.chat.getOtherName(widget.myUid);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.green.withValues(alpha: 0.15),
              child: Text(
                otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherName,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.chat.relatedItemTitle != null)
                    Text(
                      '📦 ${widget.chat.relatedItemTitle}',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Only the giver (owner of the item) can set the pickup time,
          // because the write touches the item doc and Firestore security
          // rules restrict that to the owner. participants[0] is the giver
          // per ClaimService.approveRequester's write order.
          if (widget.chat.relatedItemId != null &&
              widget.chat.participants.isNotEmpty &&
              widget.chat.participants[0] == widget.myUid)
            IconButton(
              icon: const Icon(
                Icons.schedule_rounded,
                color: AppColors.yellow,
                size: 22,
              ),
              tooltip: 'Set pickup time',
              onPressed: _pickMeetupTime,
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: chatProvider.getMessagesStream(widget.chat.id),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Say hi! Agree on a pickup time and place. 👋',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == widget.myUid;
                    switch (msg.type) {
                      case ChatMessageType.qr:
                        return _QrBubble(msg: msg, isMe: isMe);
                      case ChatMessageType.system:
                        return _SystemBubble(msg: msg);
                      case ChatMessageType.text:
                        return _MessageBubble(msg: msg, isMe: isMe);
                    }
                  },
                );
              },
            ),
          ),

          // Input bar
          _InputBar(controller: _msgCtrl, onSend: _send),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMe;

  const _MessageBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.green.withValues(alpha: 0.2),
              child: Text(
                msg.senderName.isNotEmpty
                    ? msg.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.green : AppColors.cardBg2,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.jm().format(msg.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? AppColors.white.withValues(alpha: 0.65)
                          : AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrBubble extends StatelessWidget {
  final ChatMessage msg;
  final bool isMe;
  const _QrBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final token = msg.qrToken;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: token == null
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QRDisplayScreen(
                      qrToken: token,
                      itemTitle: msg.qrItemTitle ?? 'Pickup',
                      ownerName: msg.senderName,
                    ),
                  ),
                ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.qr_code_2_rounded,
                      size: 16,
                      color: AppColors.black,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        msg.qrItemTitle ?? 'Pickup QR',
                        style: const TextStyle(
                          color: AppColors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (token != null)
                  QrImageView(
                    data: token,
                    version: QrVersions.auto,
                    size: 180,
                    backgroundColor: AppColors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.black,
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'QR not available',
                      style: TextStyle(color: AppColors.black, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'Tap to enlarge',
                  style: TextStyle(
                    color: AppColors.black.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.jm().format(msg.timestamp),
                  style: const TextStyle(color: Colors.black54, fontSize: 9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemBubble extends StatelessWidget {
  final ChatMessage msg;
  const _SystemBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.yellow.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.yellow.withValues(alpha: 0.35)),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              color: AppColors.yellow,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.white, fontSize: 14),
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Type a message…',
                hintStyle: const TextStyle(color: AppColors.mutedText),
                fillColor: AppColors.cardBg2,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.green,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: AppColors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
