import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/chat_message.dart';
import '../theme/app_theme.dart';
import 'review_card_widget.dart';
import 'zoomable_attachment_image.dart';

final _timeFmt = DateFormat('h:mm a');

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.onConfirmReview,
    this.onRejectReview,
  });

  final ChatMessage message;
  final void Function(String messageId, Map<String, String> editedFields)? onConfirmReview;
  final void Function(String messageId)? onRejectReview;

  @override
  Widget build(BuildContext context) {
    if (message.type == ChatMessageType.reviewCard && message.reviewCard != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReviewCardWidget(
              data: message.reviewCard!,
              subtitle: message.text,
              onConfirm: message.reviewCard!.isConfirmed == null
                  ? (edited) => onConfirmReview?.call(message.id, edited)
                  : null,
              onReject: message.reviewCard!.isConfirmed == null
                  ? () => onRejectReview?.call(message.id)
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4),
              child: Text(
                _timeFmt.format(message.createdAt),
                style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
              ),
            ),
          ],
        ),
      );
    }

    final isUser = message.isFromUser;
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.brightness == Brightness.dark
                  ? const Color(0xFF2C2C2C)
                  : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.type == ChatMessageType.voice) _buildVoice(context, isUser),
            if (message.type == ChatMessageType.photo) _buildPhotos(context),
            if (message.text != null && message.text!.isNotEmpty)
              Text(
                message.text!,
                style: TextStyle(
                  color: isUser ? Colors.white : theme.textTheme.bodyLarge?.color,
                ),
              ),
            if (message.status == ChatMessageStatus.sending)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Sending...',
                  style: TextStyle(
                    fontSize: 11,
                    color: isUser ? Colors.white70 : theme.hintColor,
                  ),
                ),
              ),
            if (message.status == ChatMessageStatus.failed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 14, color: AppTheme.criticalRed),
                    const SizedBox(width: 4),
                    Text(
                      'Failed to send',
                      style: TextStyle(fontSize: 11, color: AppTheme.criticalRed),
                    ),
                  ],
                ),
              ),
            if (message.status != ChatMessageStatus.sending)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  _timeFmt.format(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isUser ? Colors.white70 : theme.hintColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoice(BuildContext context, bool isUser) {
    final duration = message.audioDuration ?? const Duration(seconds: 0);
    final mins = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic, size: 18, color: isUser ? Colors.white70 : AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Text(
            '$mins:$secs',
            style: TextStyle(
              color: isUser ? Colors.white70 : null,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotos(BuildContext context) {
    if (message.attachments.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: message.attachments.map((att) {
          final localPath = att.localPath;
          if (localPath != null && File(localPath).existsSync()) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(localPath), width: 120, height: 120, fit: BoxFit.cover),
            );
          }
          if (att.storagePath.isNotEmpty) {
            return ZoomableAttachmentImage(storagePath: att.storagePath, size: 120);
          }
          return Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.image, size: 40),
          );
        }).toList(),
      ),
    );
  }
}
