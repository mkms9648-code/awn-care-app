import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/portal_escalation.dart';
import '../models/portal_message.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';
import '../widgets/portal_message_bubble.dart';

/// محادثة تصعيد واحد — بيقرا/يكتب مباشرة عن طريق SupabaseService (state
/// محلي في الشاشة، زي PatientDetailScreen)، مش عن طريق ChatProvider/ChatService
/// (دول مبنيين حوالين AI/صوت/صور/كارت مراجعة — رد الطبيب هنا نص عادي بيترحّل
/// للمريض، مفيش دور AI في نداء الطبيب نفسه).
class PortalThreadScreen extends StatefulWidget {
  const PortalThreadScreen({super.key, required this.escalation});

  final PortalEscalation escalation;

  @override
  State<PortalThreadScreen> createState() => _PortalThreadScreenState();
}

class _PortalThreadScreenState extends State<PortalThreadScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  List<PortalMessage> _messages = [];
  bool _loading = true;
  String? _error;
  bool _actionInProgress = false;
  bool _aiPaused = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final result = await context.read<SupabaseService>().portalThread(
            entryCode: auth.entryCode!,
            encounterId: widget.escalation.encounterId,
          );
      if (mounted) {
        setState(() {
          _messages = result.messages;
          _aiPaused = result.aiPaused;
        });
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendReply() async {
    final body = _textController.text.trim();
    if (body.isEmpty || _actionInProgress) return;

    setState(() => _actionInProgress = true);
    try {
      final auth = context.read<AuthProvider>();
      await context.read<SupabaseService>().portalReply(
            entryCode: auth.entryCode!,
            escalationId: widget.escalation.escalationId,
            body: body,
          );
      _textController.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: AppTheme.criticalRed),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _resolveWithoutReply() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Resolved'),
        content: const Text('Close this escalation without sending a written reply? Use this after calling the patient directly.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark Resolved')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _actionInProgress = true);
    try {
      final auth = context.read<AuthProvider>();
      await context.read<SupabaseService>().portalResolve(
            entryCode: auth.entryCode!,
            escalationId: widget.escalation.escalationId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as resolved.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: AppTheme.criticalRed),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  /// Handoff — إيقاف الـ AI عن الرد على المريض عشان الدكتور يتولى مباشرة،
  /// أو رجّعه تاني لما يخلص. حالة على مستوى الزيارة كلها مش تصعيد واحد بس.
  Future<void> _toggleAiPaused() async {
    final next = !_aiPaused;
    setState(() => _actionInProgress = true);
    try {
      final auth = context.read<AuthProvider>();
      await context.read<SupabaseService>().setPortalAiPaused(
            entryCode: auth.entryCode!,
            encounterId: widget.escalation.encounterId,
            paused: next,
          );
      if (mounted) {
        setState(() => _aiPaused = next);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next
                ? 'AI paused — you\'re handling this patient directly now.'
                : 'AI resumed for this patient.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(describeError(e)), backgroundColor: AppTheme.criticalRed),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _callPatient() async {
    final phone = widget.escalation.patientPhone;
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number on file for this patient.')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.trim());
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start a call.'), backgroundColor: AppTheme.criticalRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.escalation;
    return Scaffold(
      appBar: AppBar(
        title: Text(e.ticket != null ? '${e.patientName} — #${e.ticket}' : e.patientName),
        bottom: _aiPaused
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Container(
                  width: double.infinity,
                  color: AppTheme.accentOrange,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: const Text(
                    'AI paused — you are handling this patient directly',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(_aiPaused ? Icons.smart_toy : Icons.smart_toy_outlined),
            tooltip: _aiPaused ? 'Resume AI' : 'Take over (pause AI)',
            onPressed: _actionInProgress ? null : _toggleAiPaused,
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined),
            tooltip: 'Call patient',
            onPressed: _callPatient,
          ),
          if (_actionInProgress)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Mark resolved (no reply needed)',
              onPressed: _resolveWithoutReply,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text('No messages yet', style: TextStyle(color: Theme.of(context).hintColor)),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _messages.length,
        itemBuilder: (context, index) => PortalMessageBubble(message: _messages[index]),
      ),
    );
  }

  Widget _buildComposer() {
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
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Type a reply to the patient...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              ),
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendReply(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _actionInProgress ? null : _sendReply,
          ),
        ],
      ),
    );
  }
}
