import 'package:flutter/foundation.dart';
import '../models/push_notification.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<PushNotification> _notifications = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  int _unreadCount = 0;
  String? _error;

  List<PushNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  int get unreadCount => _unreadCount;
  String? get error => _error;

  Future<void> loadNotifications({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final items = await ApiService.fetchNotifications(page: _page);
      final parsed = items
          .map((e) => PushNotification.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (refresh || _page == 1) {
        _notifications = parsed;
      } else {
        _notifications = [..._notifications, ...parsed];
      }
      _hasMore = parsed.length >= 15;
      _page++;
    } catch (e) {
      _error = e is ApiException ? e.message : 'Could not load notifications.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUnreadCount() async {
    try {
      _unreadCount = await ApiService.fetchUnreadCount();
    } catch (_) {
      _unreadCount = 0;
    }
    notifyListeners();
  }

  Future<void> markRead(int id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1) return;
    if (_notifications[index].isRead) return;
    try {
      await ApiService.markNotificationRead(id);
      _notifications[index] = PushNotification(
        id: _notifications[index].id,
        title: _notifications[index].title,
        body: _notifications[index].body,
        type: _notifications[index].type,
        trigger: _notifications[index].trigger,
        data: _notifications[index].data,
        isRead: true,
        readAt: DateTime.now(),
        createdAt: _notifications[index].createdAt,
      );
      if (_unreadCount > 0) _unreadCount--;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await ApiService.markAllNotificationsRead();
      _notifications = _notifications
          .map((n) => PushNotification(
                id: n.id,
                title: n.title,
                body: n.body,
                type: n.type,
                trigger: n.trigger,
                data: n.data,
                isRead: true,
                readAt: n.readAt ?? DateTime.now(),
                createdAt: n.createdAt,
              ))
          .toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }
}