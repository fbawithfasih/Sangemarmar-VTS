// Renders the Order Receipt Voucher (front + back) to /tmp/test_voucher.pdf
// so the layout can be inspected without going through the live web app.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangemarmar_vts/features/billing/voucher_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Export Order Receipt Voucher PDF renders end-to-end', () async {
    final data = VoucherData(
      title: 'EXPORT ORDER RECEIPT VOUCHER',
      orderNo: 'SKC/INV/0042/26-27',
      orderDate: DateTime(2026, 5, 15),
      buyerName: 'MR. GLENN SAMUEL',
      buyerAddress: '12 PARK ROAD',
      buyerCity: 'SYDNEY',
      buyerState: 'NSW',
      buyerZip: '2000',
      buyerCountry: 'AUSTRALIA',
      buyerCellAreaCode: '+61',
      buyerCellNo: '412345678',
      buyerEmail: 'glenn@example.com',
      buyerPassportNo: 'PA1234567',
      buyerDOB: DateTime(1980, 3, 22),
      buyerNationality: 'AUSTRALIAN',
      buyerSeaPort: 'SYDNEY',
      buyerWhatsApp: '+61 412345678',
      items: [
        VoucherItem(
          quantity: 1,
          particulars: 'MARBLE INLAY TABLE TOP',
          hsnCode: '681599',
          size: '36 INCH',
          amountInr: 85000,
        ),
        VoucherItem(
          quantity: 2,
          particulars: 'DEITIES OF MARBLE GANESHA',
          hsnCode: '680299',
          size: '8 INCH',
          amountInr: 12000,
        ),
      ],
    );

    final pdf = await buildVoucherPdf(data);
    final bytes = await pdf.save();
    expect(bytes.isNotEmpty, true);
    await File('/tmp/test_voucher.pdf').writeAsBytes(bytes);
    // ignore: avoid_print
    print('Wrote /tmp/test_voucher.pdf  bytes=${bytes.length}');
  });
}
