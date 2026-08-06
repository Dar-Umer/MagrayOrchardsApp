import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'star_rating.dart';

class WriteReviewForm extends StatefulWidget {
  final int productId;
  final VoidCallback? onSubmitted;
  const WriteReviewForm({super.key, required this.productId, this.onSubmitted});

  @override
  State<WriteReviewForm> createState() => _WriteReviewFormState();
}

class _WriteReviewFormState extends State<WriteReviewForm> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() { _error = 'Please select a star rating'; });
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      await ApiService.post('/products/${widget.productId}/reviews', body: {
        'rating': _rating,
        'comment': _commentController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Review submitted! It will be visible after approval.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        _commentController.clear();
        setState(() { _rating = 0; });
        widget.onSubmitted?.call();
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Write a Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Rating: '),
              StarRating(
                rating: _rating,
                size: 28,
                interactive: true,
                onRatingChanged: (r) => setState(() { _rating = r; _error = null; }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Share your experience with this product...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Review', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
