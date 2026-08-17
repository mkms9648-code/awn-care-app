import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/portal_message.dart';
import '../theme/app_theme.dart';

final _timeFmt = DateFormat('h:mm a');

/// فقاعة رسالة بسيطة لمحادثة البورتال (مريض/AI/طبيب) — نص عادي بس، من غير
/// أي حاجة من ChatBubble (رسايل صوتية/صور/كارت مراجعة) لأنها مش موجودة هنا
/// أصلًا. الطبيب على اليمين زي أي رسالة "مني"، والمريض والـ AI على الشمال
/// بلونين مختلفين عشان تتفرق بصريًا مين اللي بيتكلم.
class PortalMessageBubble extends StatelessWidget {
  const PortalMessageBubble({super.key, required this.message});

  final PortalMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDoctor = message.sender == PortalMessageSender.doctor;
    final isAi = message.sender == PortalMessageSender.ai;

    final Color bubbleColor;
    final Color textColor;
    if (isDoctor) {
      bubbleColor = theme.colorScheme.primary;
      textColor = Colors.white;
    } else if (isAi) {
      bubbleColor = AppTheme.primaryBlue.withValues(alpha: 0.12);
      textColor = theme.textTheme.bodyLarge?.color ?? Colors.black87;
    } else {
      bubbleColor = theme.brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.white;
      textColor = theme.textTheme.bodyLarge?.color ?? Colors.black87;
    }

    return Align(
      alignment: isDoctor ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isDoctor ? 16 : 4),
            bottomRight: Radius.circular(isDoctor ? 4 : 16),
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
            if (isAi)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smart_toy_outlined, size: 14, color: AppTheme.primaryBlue),
                    const SizedBox(width: 4),
                    Text(
                      'AI Assistant',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
                    ),
                  ],
                ),
              ),
            Text(message.body, style: TextStyle(color: textColor)),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                _timeFmt.format(message.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: isDoctor ? Colors.white70 : theme.hintColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
