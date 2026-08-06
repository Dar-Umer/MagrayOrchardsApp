import 'razorpay_native_impl.dart'
    if (dart.library.js_interop) 'razorpay_web_impl.dart';
import 'razorpay_helper.dart';

RazorpayHelper createRazorpay() {
  return RazorpayPlatformImpl();
}
