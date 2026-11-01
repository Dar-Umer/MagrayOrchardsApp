import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'razorpay_helper.dart';

class RazorpayPlatformImpl implements RazorpayHelper {
  final Razorpay _razorpay = Razorpay();

  @override
  void on(String event, void Function(dynamic) handler) {
    _razorpay.on(event, (dynamic response) {
      if (response is PaymentSuccessResponse) {
        handler({
          'razorpay_payment_id': response.paymentId ?? '',
          'razorpay_order_id': response.orderId ?? '',
          'razorpay_signature': response.signature ?? '',
        });
      } else if (response is PaymentFailureResponse) {
        handler({
          'code': response.code?.toString() ?? 'ERROR',
          'message': response.message ?? '',
        });
      } else if (response is ExternalWalletResponse) {
        handler({
          'wallet_name': response.walletName ?? '',
        });
      } else {
        handler(response);
      }
    });
  }

  @override
  void open(Map<String, dynamic> options) {
    _razorpay.open(options);
  }

  @override
  void clear() {
    _razorpay.clear();
  }
}
