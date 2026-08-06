abstract class RazorpayHelper {
  void on(String event, void Function(dynamic) handler);
  void open(Map<String, dynamic> options);
  void clear();
}
