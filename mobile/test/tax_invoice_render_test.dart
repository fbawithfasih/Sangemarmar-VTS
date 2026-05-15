// Renders the Tax Invoice PDF for a known sample order and dumps it to
// /tmp/test_tax_invoice.pdf for offline inspection. Mirrors the live record
// SKC-HD/003/26-27 (MR. ALBERT EINSTEIN, US, INTER_STATE, 1 item).
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangemarmar_vts/features/billing/models/hand_delivery.dart';
import 'package:sangemarmar_vts/features/billing/tax_invoice_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Tax Invoice PDF renders end-to-end', () async {
    final order = HandDeliveryOrder(
      id: 'ord-001',
      invoiceNumber: 'SKC-HD/003/26-27',
      orderDate: DateTime(2026, 5, 6),
      status: 'DRAFT',
      invoiceType: 'INTER_STATE',
      gstin: 'NA',
      dobPassport: '13/13/1980',
      buyerName: 'MR. ALBERT EINSTEIN',
      buyerState: 'NY',
      buyerCountry: 'US',
      buyerEmail: 'einstein@example.com',
      buyerCellAreaCode: '+1',
      buyerCellNo: '5551234567',
      items: [
        HandDeliveryItem(
          id: 'it-1',
          particulars: 'WHITE MARBLE COASTERS SET',
          hsnCode: '681599',
          size: '4x4',
          quantity: 1,
          priceInr: 19047.62,
          amountInr: 20000,
          gstRate: 5,
          taxableValue: 19047.62,
          gstAmount: 952.38,
        ),
      ],
      createdAt: DateTime(2026, 5, 15),
    );

    final pdf = await buildTaxInvoicePdf(order);
    final bytes = await pdf.save();
    expect(bytes.isNotEmpty, true);
    await File('/tmp/test_tax_invoice.pdf').writeAsBytes(bytes);
    // ignore: avoid_print
    print('Wrote /tmp/test_tax_invoice.pdf  bytes=${bytes.length}');
  });
}
