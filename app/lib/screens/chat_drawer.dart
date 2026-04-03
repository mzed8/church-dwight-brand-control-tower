import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/brand_theme.dart';
import '../widgets/chat_bubble.dart';

const _examplePrompts = [
  'What\'s happening with ARM & HAMMER?',
  'Show me OxiClean\'s TikTok trend',
  'Compare ROAS across brands',
  'Summarize retailer complaints',
];

class ChatDrawer extends ConsumerStatefulWidget {
  const ChatDrawer({super.key});

  @override
  ConsumerState<ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends ConsumerState<ChatDrawer>
    with SingleTickerProviderStateMixin {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  late final AnimationController _anim;
  bool _visible = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _anim.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => _visible = true);
    _anim.forward();
  }

  void _close() {
    _anim.reverse();
    // _visible set to false via status listener
  }

  void _send(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    _inputController.clear();
    ref.read(chatMessagesProvider.notifier).sendMessage(trimmed);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final messages = ref.watch(chatMessagesProvider);

    // Listen to provider and drive animation
    ref.listen<bool>(chatOpenProvider, (prev, next) {
      if (next) {
        _open();
      } else {
        _close();
      }
    });

    if (messages.isNotEmpty) _scrollToBottom();

    if (!_visible) return const SizedBox.shrink();

    final isLoading = messages.isNotEmpty && messages.last.isLoading;

    final drawerWidth = _expanded
        ? MediaQuery.of(context).size.width * 0.8
        : (MediaQuery.of(context).size.width < 600
            ? MediaQuery.of(context).size.width
            : 400.0);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final slide = Tween(begin: 1.0, end: 0.0)
            .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic))
            .value;
        final fade = _anim.value;

        return Stack(
          children: [
            // Backdrop
            GestureDetector(
              onTap: () => ref.read(chatOpenProvider.notifier).state = false,
              child: Container(
                color: Colors.black.withValues(alpha: 0.4 * fade),
              ),
            ),
            // Drawer
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              right: 0,
              width: drawerWidth,
              child: FractionalTranslation(
                translation: Offset(slide, 0),
                child: _buildPanel(isDark, messages, isLoading),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPanel(bool isDark, List<ChatMessage> messages, bool isLoading) {
    final bgColor = isDark ? BrandColors.surfaceDark : BrandColors.surface;
    final headerBg = isDark ? BrandColors.navy : BrandColors.blue;

    return Material(
      color: bgColor,
      elevation: 16,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: headerBg,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Brand Control Tower Agent',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Multi-Agent Supervisor — routes to CHD Brand Intelligence and CHD_Complaint_Docs',
                            child: Icon(Icons.info_outline_rounded, size: 14, color: Colors.white70),
                          ),
                        ],
                      ),
                      const Text('Multi-agent supervisor',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                if (messages.isNotEmpty)
                  IconButton(
                    onPressed: () => ref.read(chatMessagesProvider.notifier).clear(),
                    icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 20),
                    tooltip: 'Clear chat',
                  ),
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.close_fullscreen : Icons.open_in_full,
                    color: Colors.white70, size: 18,
                  ),
                  tooltip: _expanded ? 'Collapse' : 'Expand',
                ),
                IconButton(
                  onPressed: () => ref.read(chatOpenProvider.notifier).state = false,
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_outlined, size: 48,
                            color: isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary),
                        const SizedBox(height: 16),
                        Text('Ask about brand health, marketing\nperformance, or retailer complaints',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary,
                                fontSize: 14, height: 1.5)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, i) => ChatBubble(message: messages[i], isDark: isDark),
                  ),
          ),

          // Bottom bar
          Container(
            decoration: BoxDecoration(
              color: isDark ? BrandColors.navy : Colors.white,
              border: Border(top: BorderSide(color: isDark ? BrandColors.borderDark : BrandColors.border)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Prompt chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _examplePrompts.map((p) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(p, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                            color: isDark ? BrandColors.textSecondaryDark : BrandColors.blue)),
                        backgroundColor: isDark ? BrandColors.cardDark : BrandColors.blueLight,
                        side: BorderSide(color: isDark ? BrandColors.borderDark : BrandColors.border),
                        onPressed: isLoading ? null : () => _send(p),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                // Input row
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _inputController,
                          enabled: !isLoading,
                          style: TextStyle(
                            color: isDark ? BrandColors.textDark : BrandColors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Ask the Brand Intelligence Agent...',
                            hintStyle: TextStyle(
                                color: isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary, fontSize: 14),
                            filled: true,
                            fillColor: isDark ? BrandColors.cardDark : BrandColors.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? BrandColors.borderDark : BrandColors.border)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? BrandColors.borderDark : BrandColors.border)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: BrandColors.blue, width: 1.5)),
                          ),
                          onSubmitted: isLoading ? null : _send,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40, height: 40,
                      child: IconButton(
                        onPressed: isLoading ? null : () => _send(_inputController.text),
                        style: IconButton.styleFrom(
                          backgroundColor: isLoading ? BrandColors.textSecondary : BrandColors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
