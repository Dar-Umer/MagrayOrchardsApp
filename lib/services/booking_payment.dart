import 'dart:async';
import 'api_service.dart';
import 'razorpay_factory.dart';

enum BookingPaymentResult { success, failed, cancelled }

/// Reusable Razorpay flow for service bookings: creates the order, opens the
/// checkout, verifies the payment, and resolves once the modal is dismissed.
class BookingPayment {
  static Future<BookingPaymentResult> start({
    required int bookingId,
    required String description,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
  }) async {
    final order = await ApiService.createBookingPayment(bookingId);

    final razorpay = createRazorpay();
    final completer = Completer<BookingPaymentResult>();

    razorpay.on('payment.success', (response) async {
      try {
        await ApiService.verifyBookingPayment(
          bookingId,
          razorpayOrderId: (response['razorpay_order_id'] as String?) ?? '',
          razorpayPaymentId: (response['razorpay_payment_id'] as String?) ?? '',
          razorpaySignature: (response['razorpay_signature'] as String?) ?? '',
        );
        if (!completer.isCompleted) {
          completer.complete(BookingPaymentResult.success);
        }
      } catch (_) {
        if (!completer.isCompleted) {
          completer.complete(BookingPaymentResult.failed);
        }
      } finally {
        razorpay.clear();
      }
    });

    razorpay.on('payment.error', (error) {
      final code = error is Map ? error['code'] : null;
      final cancelled = code == 'CANCELLED' || code == 'PAYMENT_CANCELLED';
      if (!completer.isCompleted) {
        completer.complete(cancelled
            ? BookingPaymentResult.cancelled
            : BookingPaymentResult.failed);
      }
      razorpay.clear();
    });

    final dynamic rawAmount = order['amount'];
    final double amountInRupees = rawAmount is num
        ? rawAmount.toDouble()
        : (double.tryParse(rawAmount?.toString() ?? '') ?? 0.0);
    final int amountInPaise = (amountInRupees * 100).round();

    try {
      razorpay.open({
        'key': order['key'] ?? '',
        'order_id': order['razorpay_order_id'],
        'amount': amountInPaise,
        'currency': 'INR',
        'name': 'Magray Orchards',
        'description': description,
        'prefill': {
          'name': customerName ?? '',
          'email': customerEmail ?? '',
          'contact': customerPhone ?? '',
        },
      });
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(BookingPaymentResult.failed);
      }
      razorpay.clear();
    }

    return completer.future;
  }
}
