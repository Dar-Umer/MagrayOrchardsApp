import 'dart:html' as html;
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_util' as js_util;
import 'razorpay_helper.dart';

class RazorpayPlatformImpl implements RazorpayHelper {
  void Function(dynamic)? _onSuccess;
  void Function(dynamic)? _onError;

  @override
  void on(String event, void Function(dynamic) handler) {
    if (event == 'payment.success') _onSuccess = handler;
    if (event == 'payment.error') _onError = handler;
  }

  @override
  void open(Map<String, dynamic> options) {
    _loadScript().then((_) => _doOpen(options));
  }

  @override
  void clear() {
    _onSuccess = null;
    _onError = null;
  }

  Future<void> _loadScript() async {
    if (html.document.querySelector('script[src*="checkout.razorpay.com"]') != null) return;
    final completer = Completer<void>();
    final script = html.ScriptElement()
      ..src = 'https://checkout.razorpay.com/v1/checkout.js'
      ..async = true;
    script.addEventListener('load', (_) => completer.complete());
    script.addEventListener('error', (_) =>
        completer.completeError(Exception('Failed to load Razorpay SDK')));
    html.document.head!.append(script);
    return completer.future;
  }

  void _doOpen(Map<String, dynamic> opts) {
    final handler = _onSuccess;
    final dismiss = _onError;

    // Register a global Dart callback so JavaScript can call it.
    js_util.setProperty(
      js_util.globalThis,
      '_rzpSuccess'.toJS,
      js_util.allowInterop((dynamic pid, dynamic oid, dynamic sig) {
        if (handler != null) {
          handler({
            'razorpay_payment_id': pid?.toString() ?? '',
            'razorpay_order_id': oid?.toString() ?? '',
            'razorpay_signature': sig?.toString() ?? '',
          });
        }
      }),
    );

    js_util.setProperty(
      js_util.globalThis,
      '_rzpDismiss'.toJS,
      js_util.allowInterop(() {
        if (dismiss != null) {
          dismiss({'message': 'Payment cancelled by user', 'code': 'CANCELLED'});
        }
      }),
    );

    // Use JSON to safely encode string values and avoid JS injection via string interpolation.
    String jsStr(dynamic v) => v?.toString().replaceAll("'", "\\'").replaceAll('\n', '\\n') ?? '';
    final jsKey = jsStr(opts['key']);
    final jsAmount = jsStr(opts['amount']);
    final jsCurrency = jsStr(opts['currency'] ?? 'INR');
    final jsName = jsStr(opts['name'] ?? 'Magray Orchards');
    final jsDesc = jsStr(opts['description'] ?? '');
    final jsOrderId = jsStr(opts['order_id']);
    final jsPName = jsStr(opts['prefill']?['name'] ?? '');
    final jsPEmail = jsStr(opts['prefill']?['email'] ?? '');
    final jsPContact = jsStr(opts['prefill']?['contact'] ?? '');

    // Inject a <script> element with the Razorpay checkout code.
    final script = html.ScriptElement()
      ..text = '''
(function() {
  try {
    var rzp = new Razorpay({
      key: '$jsKey',
      amount: '$jsAmount',
      currency: '$jsCurrency',
      name: '$jsName',
      description: '$jsDesc',
      order_id: '$jsOrderId',
      prefill: { name: '$jsPName', email: '$jsPEmail', contact: '$jsPContact' },
      handler: function(r) {
        window._rzpSuccess(r.razorpay_payment_id, r.razorpay_order_id, r.razorpay_signature);
      },
      modal: {
        ondismiss: function() { window._rzpDismiss(); }
      }
    });
    rzp.open();
  } catch(e) {
    console.error('Razorpay error:', e);
  }
})();
''';
    html.document.body!.append(script);
    script.remove();
  }
}
