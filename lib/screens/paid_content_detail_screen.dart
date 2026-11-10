import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/paid_content.dart';

class PaidContentDetailScreen extends StatefulWidget {
  final String slug;
  const PaidContentDetailScreen({super.key, required this.slug});

  @override
  State<PaidContentDetailScreen> createState() => _PaidContentDetailScreenState();
}

class _PaidContentDetailScreenState extends State<PaidContentDetailScreen> {
  PaidContent? _content;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final response = await ApiService.get('paid-contents/${widget.slug}');
      setState(() {
        _content = PaidContent.fromJson(response['data']);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load this content. Please check your connection and try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_content?.title ?? 'Content'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _content == null
              ? const Center(child: Text('Content not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _content!.contentType == 'spray_schedule'
                              ? Colors.blue.shade50
                              : _content!.contentType == 'nutrition'
                                  ? Colors.green.shade50
                                  : Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _content!.contentTypeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _content!.contentType == 'spray_schedule'
                                ? Colors.blue.shade700
                                : _content!.contentType == 'nutrition'
                                    ? Colors.green.shade700
                                    : Colors.purple.shade700,
                          ),
                        ),
                      ),
                      if (_content!.requiredPlanName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Requires: ${_content!.requiredPlanName}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_content!.summary != null)
                        Text(_content!.summary!,
                            style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
                      const SizedBox(height: 16),
                      Text(_content!.body, style: const TextStyle(fontSize: 15, height: 1.6)),
                    ],
                  ),
                ),
    );
  }
}
