import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bubble.dart';

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// فاصل تاريخ زي تيليجرام — "Today"/"Yesterday"/تاريخ كامل — بيظهر أول رسالة
/// كل يوم جديد في المحادثة.
class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date});

  final DateTime date;

  static final _fullFmt = DateFormat('MMMM d, yyyy');

  String _label() {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(date, yesterday)) return 'Yesterday';
    return _fullFmt.format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.hintColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _label(),
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: theme.hintColor),
          ),
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.title = 'Chat'});

  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  bool _showTextInput = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;
    await context.read<ChatProvider>().sendPhoto(File(file.path));
    _scrollToBottom();
  }

  void _showAttachOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    _scrollToBottom();

    // بيوري السبب الحقيقي لأي فشل (رفع ملف، اتصال، إلخ) بدل ما يفضل "Failed
    // to send" من غير تفاصيل — يساعد في التشخيص السريع لو حصل خطأ.
    if (chat.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(chat.error!), backgroundColor: AppTheme.criticalRed),
        );
        chat.clearError();
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: chat.messages.isEmpty
                ? Center(
                    child: Text(
                      'Start a conversation',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: chat.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chat.messages[index];
                      final showDateHeader =
                          index == 0 || !_isSameDay(chat.messages[index - 1].createdAt, msg.createdAt);
                      return Column(
                        children: [
                          if (showDateHeader) _DateHeader(date: msg.createdAt),
                          ChatBubble(
                            message: msg,
                            onConfirmReview: chat.confirmReviewCard,
                            onRejectReview: chat.rejectReviewCard,
                          ),
                        ],
                      );
                    },
                  ),
          ),
          if (chat.isRecording)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppTheme.criticalRed.withValues(alpha: 0.08),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: AppTheme.criticalRed),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Recording... Tap mic to send', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  TextButton(onPressed: chat.cancelRecording, child: const Text('Cancel')),
                ],
              ),
            ),
          _buildInputBar(chat),
        ],
      ),
    );
  }

  Widget _buildInputBar(ChatProvider chat) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: chat.isSending ? null : _showAttachOptions,
            tooltip: 'Attach photo',
          ),
          IconButton(
            icon: Icon(_showTextInput ? Icons.keyboard_hide : Icons.keyboard),
            onPressed: () => setState(() => _showTextInput = !_showTextInput),
            tooltip: 'Toggle text input',
          ),
          if (_showTextInput)
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendText(chat),
              ),
            )
          else
            const Spacer(),
          if (_showTextInput)
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: chat.isSending ? null : () => _sendText(chat),
            ),
          FloatingActionButton(
            mini: true,
            onPressed: chat.isSending
                ? null
                : () async {
                    if (chat.isRecording) {
                      await chat.stopRecordingAndSend();
                    } else {
                      await chat.startRecording();
                    }
                    _scrollToBottom();
                  },
            backgroundColor: chat.isRecording ? AppTheme.criticalRed : AppTheme.primaryBlue,
            child: Icon(chat.isRecording ? Icons.stop : Icons.mic),
          ),
        ],
      ),
    );
  }

  Future<void> _sendText(ChatProvider chat) async {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    await chat.sendText(text);
    _scrollToBottom();
  }
}
