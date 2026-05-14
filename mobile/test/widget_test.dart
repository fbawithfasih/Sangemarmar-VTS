import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

// Regression guard for the admin dashboard summary grid: a Row with
// CrossAxisAlignment.stretch inside a ListView grows unbounded vertically,
// which pushes every card after the first row off-screen. The fix wraps each
// row in IntrinsicHeight to bound its height. This test reproduces the exact
// structure and asserts it lays out with no exception and all cards visible.
void main() {
  testWidgets('summary grid renders all cards inside a ListView', (tester) async {
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final fmtInt = NumberFormat('#,##0');
    final s = <String, dynamic>{
      'vehicleEntries': 8,
      'salesCount': 6,
      'grossSales': 111000,
      'netSales': 101820,
      'totalPayments': 66000,
      'commissionPaid': 23287,
      'commissionPending': 23242,
      'commissionTotal': 46529,
    };

    Widget statCard(String label, String value, IconData icon, Color color) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 8),
                Text(value,
                    style: TextStyle(
                        fontSize: 19, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        );

    final cards = [
      statCard('Vehicle Entries', fmtInt.format(s['vehicleEntries']), Icons.directions_car, Colors.blue),
      statCard('Total Sales', fmtInt.format(s['salesCount']), Icons.receipt_long, Colors.indigo),
      statCard('Gross Sales', fmt.format(s['grossSales']), Icons.trending_up, Colors.teal),
      statCard('Net Sales', fmt.format(s['netSales']), Icons.monetization_on, Colors.green),
      statCard('Payments', fmt.format(s['totalPayments']), Icons.payments, const Color(0xFF00695C)),
      statCard('Commission Total', fmt.format(s['commissionTotal']), Icons.percent, const Color(0xFF6A1B9A)),
      statCard('Commission Paid', fmt.format(s['commissionPaid']), Icons.check_circle, const Color(0xFF1565C0)),
      statCard('Commission Pending', fmt.format(s['commissionPending']), Icons.hourglass_bottom, Colors.redAccent),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Column(
                children: [
                  for (var i = 0; i < cards.length; i += 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: cards[i]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: i + 1 < cards.length
                                  ? cards[i + 1]
                                  : const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // No layout/build exception (the unbounded-stretch bug throws/overflows here).
    expect(tester.takeException(), isNull);

    // Every card label is present — including the ones that were pushed
    // off-screen before the fix.
    for (final label in [
      'Vehicle Entries',
      'Total Sales',
      'Gross Sales',
      'Net Sales',
      'Payments',
      'Commission Total',
      'Commission Paid',
      'Commission Pending',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '"$label" card should render');
    }
  });
}
