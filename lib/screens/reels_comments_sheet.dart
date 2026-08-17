import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reels_provider.dart';

class ReelsCommentsSheet extends StatefulWidget {
  final int reelId;
  const ReelsCommentsSheet({super.key, required this.reelId});

  @override
  State<ReelsCommentsSheet> createState() => _ReelsCommentsSheetState();
}

class _ReelsCommentsSheetState extends State<ReelsCommentsSheet> {
  final _controller = TextEditingController();
  List<dynamic> _comments = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final provider = context.read<ReelsProvider>();
    final comments = await provider.fetchComments(widget.reelId);
    if (mounted) {
      setState(() {
        _comments = comments;
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    setState(() => _submitting = true);
    final provider = context.read<ReelsProvider>();
    final comment = await provider.addComment(widget.reelId, body);
    if (mounted) {
      setState(() {
        _submitting = false;
        if (comment != null) {
          _comments.insert(0, comment);
          _controller.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              )),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Text('No comments yet',
                                    style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _comments.length,
                            itemBuilder: (context, i) {
                              final c = _comments[i];
                              return _CommentTile(comment: c);
                            },
                          ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          isDense: true,
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _submitting ? null : _submit,
                      icon: const Icon(Icons.send),
                      color: scheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final dynamic comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final userName = comment.userName ?? 'User';
    final body = comment.body ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
