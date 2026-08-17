import 'package:flutter/material.dart';
import '../models/reel.dart';
import '../models/reel_comment.dart';
import '../services/api_service.dart';

class ReelsProvider extends ChangeNotifier {
  List<Reel> _reels = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  void clearError() { _errorMessage = null; notifyListeners(); }

  List<Reel> get reels => _reels;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  Future<void> fetchReels({bool refresh = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }
    notifyListeners();
    try {
      final queryParams = <String, String>{'page': '$_currentPage', 'per_page': '10'};
      final response = await ApiService.get('/reels', queryParams: queryParams);
      final envelope = response['data'];
      List<dynamic> items;
      int? lastPage;
      if (envelope is Map && envelope.containsKey('data')) {
        items = envelope['data'] ?? [];
        lastPage = envelope['last_page'] is num
            ? (envelope['last_page'] as num).toInt()
            : null;
      } else if (envelope is List) {
        items = envelope;
      } else {
        items = [];
      }
      final loaded = items.map((e) => Reel.fromJson(Map<String, dynamic>.from(e))).toList();
      if (refresh || _currentPage == 1) {
        _reels = loaded;
      } else {
        _reels = [..._reels, ...loaded];
      }
      _hasMore = loaded.isNotEmpty && (lastPage == null || _currentPage < lastPage);
      _currentPage++;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load reels.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleLike(Reel reel) async {
    try {
      final response = await ApiService.post('/reels/${reel.id}/like');
      final data = response['data'] ?? response;
      final liked = data['liked'] ?? false;
      final count = data['likes_count'] is num
          ? (data['likes_count'] as num).toInt()
          : (liked ? reel.likesCount + 1 : (reel.likesCount - 1).clamp(0, 1 << 31));
      final index = _reels.indexWhere((r) => r.id == reel.id);
      if (index >= 0) {
        _reels[index] = reel.copyWith(
          isLiked: liked,
          likesCount: count,
        );
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not update like.';
      notifyListeners();
    }
  }

  Future<List<ReelComment>> fetchComments(int reelId) async {
    try {
      final response = await ApiService.get('/reels/$reelId/comments');
      final data = response['data'] ?? response;
      return (data as List)
          .map((e) => ReelComment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load comments.';
      return [];
    }
  }

  Future<ReelComment?> addComment(int reelId, String body) async {
    try {
      final response = await ApiService.post('/reels/$reelId/comments', body: {
        'body': body,
      });
      final data = response['data'] ?? response;
      final comment = ReelComment.fromJson(Map<String, dynamic>.from(data));
      final count = data['comments_count'] is num
          ? (data['comments_count'] as num).toInt()
          : null;
      if (count != null) {
        final index = _reels.indexWhere((r) => r.id == reelId);
        if (index >= 0) {
          _reels[index] = _reels[index].copyWith(commentsCount: count);
          notifyListeners();
        }
      }
      return comment;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not add comment.';
      return null;
    }
  }
}
