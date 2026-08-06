import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'razorpay_helper.dart';

class RazorpayPlatformImpl implements RazorpayHelper {
  final Razorpay _razorpay = Razorpay();

  @override
  void on(String event, void Function(dynamic) handler) {
    _razorpay.on(event, (response) => handler(response));
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
