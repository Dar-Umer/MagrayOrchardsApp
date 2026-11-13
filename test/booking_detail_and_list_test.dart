import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magray_orchards/models/service_booking.dart';
import 'package:magray_orchards/providers/auth_provider.dart';
import 'package:magray_orchards/screens/booking_detail_screen.dart';
import 'package:magray_orchards/screens/my_bookings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final samplePendingBooking = ServiceBookingModel(
    id: 8,
    serviceId: 1,
    serviceName: 'Orchard Pruning Service',
    serviceSlug: 'orchard-pruning-service',
    bookingDate: DateTime(2026, 11, 25),
    timeSlot: 'morning',
    address: 'Pulwama Orchard Block A',
    latitude: 33.87161,
    longitude: 74.89457,
    distanceKm: 12.0,
    travelCharge: 100.0,
    baseCharge: 500.0,
    totalAmount: 600.0,
    quantity: 10,
    priceUnit: 'per_tree',
    notes: 'Please bring high-reach poles',
    orchardDetails: '10 mature apple trees near south boundary',
    status: 'pending',
    paymentStatus: 'unpaid',
    paymentMethod: 'visit',
    assignedStaffId: 3,
    assignedStaffName: 'Mushtaq Ahmad',
    assignedStaffPhone: '+919419012345',
    assignedStaffRole: 'Senior Orchard Agronomist',
    createdAt: DateTime(2026, 11, 14, 1, 4),
  );

  final sampleConfirmedPaidBooking = ServiceBookingModel(
    id: 9,
    serviceId: 2,
    serviceName: 'Professional Spraying Service',
    serviceSlug: 'professional-spraying-service',
    bookingDate: DateTime(2026, 11, 26),
    timeSlot: 'afternoon',
    address: 'Shopian Farm B',
    latitude: 33.72,
    longitude: 74.83,
    distanceKm: 0.0,
    travelCharge: 0.0,
    baseCharge: 1200.0,
    totalAmount: 1200.0,
    quantity: 8,
    priceUnit: 'per_kanal',
    status: 'confirmed',
    paymentStatus: 'paid',
    paymentMethod: 'online',
    razorpayOrderId: 'order_test_12345',
    razorpayPaymentId: 'pay_test_98765',
    createdAt: DateTime(2026, 11, 14, 1, 10),
  );

  group('Service Booking List & Detail Tests', () {
    test('ServiceBookingModel computes bookingNumber and isCancellable correctly', () {
      expect(samplePendingBooking.bookingNumber, '#BK-0008');
      expect(samplePendingBooking.shortBookingNumber, '#8');
      expect(samplePendingBooking.isCancellable, true);
      expect(samplePendingBooking.hasAssignedStaff, true);
      expect(samplePendingBooking.hasAssignedStaffPhone, true);

      expect(sampleConfirmedPaidBooking.bookingNumber, '#BK-0009');
      expect(sampleConfirmedPaidBooking.isCancellable, false);
      expect(sampleConfirmedPaidBooking.isPaid, true);
      expect(sampleConfirmedPaidBooking.hasAssignedStaff, false);
    });

    testWidgets('BookingDetailScreen displays assigned staff, call button, and cancel action',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: BookingDetailScreen(booking: samplePendingBooking),
          ),
        ),
      );

      await tester.pump();

      // Header info
      expect(find.text('#BK-0008'), findsOneWidget);
      expect(find.text('Orchard Pruning Service'), findsOneWidget);

      // Status info
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.text('UNPAID'), findsNWidgets(2));

      // Assigned Staff section
      expect(find.text('Assigned Specialist'), findsOneWidget);
      expect(find.text('Mushtaq Ahmad'), findsOneWidget);
      expect(find.text('Senior Orchard Agronomist'), findsOneWidget);
      expect(find.text('+919419012345'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Call'), findsOneWidget);

      // Cancel button present for pending unpaid
      final cancelBtn = find.widgetWithText(OutlinedButton, 'Cancel Booking');
      expect(cancelBtn, findsOneWidget);

      // Scroll into view & tap Cancel Booking -> shows confirmation dialog
      await tester.ensureVisible(cancelBtn);
      await tester.pumpAndSettle();
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(find.text('Cancel Booking?'), findsOneWidget);
      expect(find.text('Keep Booking'), findsOneWidget);
      expect(find.text('Yes, Cancel Booking'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Keep Booking'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel Booking?'), findsNothing);
    });

    testWidgets('BookingDetailScreen hides Cancel button for confirmed and paid bookings',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: BookingDetailScreen(booking: sampleConfirmedPaidBooking),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('#BK-0009'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('PAID'), findsNWidgets(2));

      // No cancel button
      expect(find.text('Cancel Booking'), findsNothing);

      // No assigned staff notice shown
      expect(find.textContaining('A certified orchard specialist will be assigned shortly'), findsOneWidget);

      // Payment details
      expect(find.text('Razorpay Order ID'), findsOneWidget);
      expect(find.text('order_test_12345'), findsOneWidget);
      expect(find.text('Payment Reference'), findsOneWidget);
      expect(find.text('pay_test_98765'), findsOneWidget);
    });
  });
}
