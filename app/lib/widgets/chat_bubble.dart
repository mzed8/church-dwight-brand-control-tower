import 'dart:convert';
import 'dart:math' as math;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';
import '../theme/brand_theme.dart';

void _downloadResponse(String content, String filename) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/plain');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// A single chat bubble for user or assistant messages.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isDark,
  });

  bool get _isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    final mutedColor =
        isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isUser) ...[
            _agentAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              child: Column(
                crossAxisAlignment:
                    _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  _bubbleBody(context),
                  if (!_isUser && !message.isLoading)
                    Padding(
                      padding: const EdgeInsets.only(left: 0, top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.copy, size: 14, color: mutedColor),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: message.content));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied to clipboard'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            tooltip: 'Copy',
                            iconSize: 14,
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(Icons.download,
                                size: 14, color: mutedColor),
                            onPressed: () => _downloadResponse(
                              message.content,
                              'brand-intelligence-response.txt',
                            ),
                            tooltip: 'Download',
                            iconSize: 14,
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  _timestamp(),
                ],
              ),
            ),
          ),
          if (_isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _agentAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: BrandColors.blue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
    );
  }

  Widget _bubbleBody(BuildContext context) {
    final bgColor = _isUser
        ? BrandColors.blue
        : (isDark ? BrandColors.cardDark : Colors.white);

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(_isUser ? 16 : 4),
      bottomRight: Radius.circular(_isUser ? 4 : 16),
    );

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
        border: _isUser
            ? null
            : Border.all(
                color: isDark ? BrandColors.borderDark : BrandColors.border,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: message.isLoading ? const _AnimatedDots() : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    if (_isUser) {
      return Text(
        message.content,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.45,
        ),
      );
    }

    // Assistant messages rendered as Markdown
    final textColor = isDark ? BrandColors.textDark : BrandColors.textPrimary;
    final codeBlockBg = isDark ? BrandColors.navy : BrandColors.blueLight;

    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.8;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: maxBubbleWidth * 0.5,
          maxWidth: maxBubbleWidth * 2,
        ),
        child: MarkdownBody(
          data: message.content,
          selectable: true,
          shrinkWrap: true,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(color: textColor, fontSize: 14, height: 1.5),
            strong: TextStyle(
                color: textColor, fontSize: 14, fontWeight: FontWeight.w700),
            em: TextStyle(
                color: textColor, fontSize: 14, fontStyle: FontStyle.italic),
            h1: TextStyle(
                color: textColor, fontSize: 20, fontWeight: FontWeight.w700),
            h2: TextStyle(
                color: textColor, fontSize: 17, fontWeight: FontWeight.w600),
            h3: TextStyle(
                color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
            listBullet: TextStyle(color: textColor, fontSize: 14),
            code: TextStyle(
              color: BrandColors.gold,
              backgroundColor: codeBlockBg,
              fontSize: 13,
            ),
            codeblockDecoration: BoxDecoration(
              color: codeBlockBg,
              borderRadius: BorderRadius.circular(8),
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: BrandColors.blue, width: 3),
              ),
            ),
            tableBorder: TableBorder.all(
              color: isDark ? BrandColors.borderDark : BrandColors.border,
            ),
            tableBody: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            tableHead: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  }

  Widget _timestamp() {
    final time = message.timestamp;
    final label =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Text(
      label,
      style: TextStyle(
        color: isDark ? BrandColors.textSecondaryDark : BrandColors.textSecondary,
        fontSize: 11,
      ),
    );
  }
}

/// Three animated opacity dots to indicate the assistant is thinking.
class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots();

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Stagger each dot by 0.2
            final delay = i * 0.2;
            final t = (_controller.value - delay) % 1.0;
            // Pulse opacity between 0.3 and 1.0
            final opacity =
                0.3 + 0.7 * (0.5 + 0.5 * math.cos(t * 2 * math.pi));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: BrandColors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
