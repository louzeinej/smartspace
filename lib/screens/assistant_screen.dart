import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/assistant_service.dart';
import '../theme/app_theme.dart';

/// Écran de chat avec l'assistant SmartSpace (valeur ajoutée).
/// L'assistant interroge la base SQLite locale pour répondre —
/// 100 % offline, aucune donnée envoyée à un serveur.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [
    _ChatMessage.assistant(
      'Bonjour 👋 Je suis l\'assistant SmartSpace.\n\n'
      'Essayez : « cherche Youssef », « combien de développeurs ? »,\n'
      '« qui est administrateur ? » ou « j\'ai oublié mon mot de passe ».',
    ),
  ];
  bool _thinking = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _thinking) return;
    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage.user(text));
      _thinking = true;
    });
    _scrollToBottom();

    // Petite latence pour un rendu « conversationnel » naturel.
    final reply = await AssistantService.instance.respond(
      text,
      userName: context.read<AuthProvider>().currentUser?.fullName,
    );
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage.assistant(reply));
      _thinking = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant SmartSpace')),
      body: Column(
        children: [
          // ── Fil de discussion ──
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: _Bubble(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  );
                }
                final m = _messages[i];
                return Align(
                  alignment: m.fromUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: _Bubble(child: Text(m.text)),
                );
              },
            ),
          ),

          // ── Barre de saisie ──
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8,
                      offset: Offset(0, -2)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Posez votre question…',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFFD9D9E3)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                      onPressed: _send,
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

/// Bulle de message : violette pour l'assistant, dégradée pour l'utilisateur.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        child: child,
      ),
    );
  }
}

class _ChatMessage {
  _ChatMessage._(this.text, this.fromUser);
  _ChatMessage.user(String text) : this._(text, true);
  _ChatMessage.assistant(String text) : this._(text, false);

  final String text;
  final bool fromUser;
}
