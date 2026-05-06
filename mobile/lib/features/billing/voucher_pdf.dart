import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class VoucherCompany {
  static const name = 'S.K. COTTAGE INDUSTRIES';
  static const subtitle = 'Manufacturers & Exporters of: Handmade Marble Inlay Handicrafts & Textiles';
  static const address = 'A/C-2/2, TAJ NAGRI, PHASE II, AGRA-282001 (INDIA)';
  static const gstin = '09ADAPK6665Q1ZT';
  static const iec = '0607000473';
  static const bankName = 'IDBI BANK LTD, TAJGANJ';
  static const bankBranch = 'FATEHABAD ROAD, AGRA';
  static const bankAccount = '303102000000426';
  static const bankIfsc = 'IBKL0000303';
  static const bankSwift = 'IBKLINBBD18';
}

class VoucherItem {
  final int quantity;
  final String particulars;
  final String? hsnCode;
  final String? size;
  final double amountInr;
  VoucherItem({
    required this.quantity,
    required this.particulars,
    this.hsnCode,
    this.size,
    required this.amountInr,
  });
}

class VoucherData {
  final String title; // e.g. 'EXPORT ORDER RECEIPT VOUCHER' or 'HAND DELIVERY VOUCHER'
  final String orderNo;
  final DateTime orderDate;

  final String buyerName;
  final String buyerAddress;
  final String buyerCity;
  final String buyerState;
  final String buyerZip;
  final String buyerCountry;
  final String? buyerCellAreaCode;
  final String? buyerCellNo;
  final String buyerEmail;
  final String buyerPassportNo;
  final DateTime? buyerDOB;
  final String buyerNationality;
  final String buyerSeaPort;
  final String buyerWhatsApp;

  final List<VoucherItem> items;

  VoucherData({
    required this.title,
    required this.orderNo,
    required this.orderDate,
    required this.buyerName,
    required this.buyerAddress,
    required this.buyerCity,
    required this.buyerState,
    required this.buyerZip,
    required this.buyerCountry,
    this.buyerCellAreaCode,
    this.buyerCellNo,
    required this.buyerEmail,
    required this.buyerPassportNo,
    this.buyerDOB,
    required this.buyerNationality,
    required this.buyerSeaPort,
    required this.buyerWhatsApp,
    required this.items,
  });
}

String _amountInWords(double amount) {
  const ones = ['', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE',
    'TEN', 'ELEVEN', 'TWELVE', 'THIRTEEN', 'FOURTEEN', 'FIFTEEN', 'SIXTEEN', 'SEVENTEEN', 'EIGHTEEN', 'NINETEEN'];
  const tens = ['', '', 'TWENTY', 'THIRTY', 'FORTY', 'FIFTY', 'SIXTY', 'SEVENTY', 'EIGHTY', 'NINETY'];

  String hundreds(int n) {
    var s = '';
    if (n >= 100) { s += '${ones[n ~/ 100]} HUNDRED '; n %= 100; }
    if (n >= 20) { s += '${tens[n ~/ 10]} '; n %= 10; }
    if (n > 0) s += '${ones[n]} ';
    return s.trim();
  }

  String indian(int n) {
    if (n == 0) return 'ZERO';
    var s = '';
    final crore = n ~/ 10000000; n %= 10000000;
    final lakh = n ~/ 100000; n %= 100000;
    final thousand = n ~/ 1000; n %= 1000;
    if (crore > 0) s += '${hundreds(crore)} CRORE ';
    if (lakh > 0) s += '${hundreds(lakh)} LAKH ';
    if (thousand > 0) s += '${hundreds(thousand)} THOUSAND ';
    if (n > 0) s += hundreds(n);
    return s.trim();
  }

  final rupees = amount.floor();
  final paise = ((amount - rupees) * 100).round();
  final r = indian(rupees);
  if (paise > 0) return 'RUPEES $r AND ${hundreds(paise)} PAISE ONLY';
  return 'RUPEES $r ONLY';
}

Future<pw.Document> buildVoucherPdf(VoucherData d) async {
  final doc = pw.Document();
  final dtFmt = DateFormat('dd MMM yyyy');
  final total = d.items.fold(0.0, (s, i) => s + i.amountInr);
  final totalQty = d.items.fold(0, (s, i) => s + i.quantity);
  final cell = (d.buyerCellAreaCode != null && d.buyerCellAreaCode!.isNotEmpty) ||
          (d.buyerCellNo != null && d.buyerCellNo!.isNotEmpty)
      ? '${d.buyerCellAreaCode ?? ''} ${d.buyerCellNo ?? ''}'.trim()
      : '—';

  pw.Widget kv(String k, String v) => pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(text: '$k: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
          pw.TextSpan(text: v, style: const pw.TextStyle(fontSize: 8.5)),
        ]),
      );

  pw.Widget buyerRow(String l1, String v1, String l2, String v2) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.Expanded(child: kv(l1, v1)),
          pw.Expanded(child: kv(l2, v2)),
        ]),
      );

  // ── Page 1: Voucher front ──
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Header
        pw.Center(child: pw.Text(VoucherCompany.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 2),
        pw.Center(child: pw.Text(VoucherCompany.subtitle, style: const pw.TextStyle(fontSize: 8.5))),
        pw.Center(child: pw.Text(VoucherCompany.address, style: const pw.TextStyle(fontSize: 8))),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text(d.title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 2),
        pw.Center(child: pw.Text('GSTIN: ${VoucherCompany.gstin}     IEC: ${VoucherCompany.iec}', style: const pw.TextStyle(fontSize: 8))),
        pw.Divider(thickness: 0.6),

        // Bank + Order info
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            flex: 6,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Bank Details:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.Text('${VoucherCompany.bankName}, ${VoucherCompany.bankBranch}', style: const pw.TextStyle(fontSize: 8.5)),
              pw.Text('A/c No: ${VoucherCompany.bankAccount}', style: const pw.TextStyle(fontSize: 8.5)),
              pw.Text('IFSC: ${VoucherCompany.bankIfsc}    SWIFT: ${VoucherCompany.bankSwift}', style: const pw.TextStyle(fontSize: 8.5)),
            ]),
          ),
          pw.Expanded(
            flex: 4,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              kv('Order No', d.orderNo),
              pw.SizedBox(height: 4),
              kv('Date', dtFmt.format(d.orderDate.toLocal())),
            ]),
          ),
        ]),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.6), bottom: pw.BorderSide(width: 0.6))),
          child: pw.Center(child: pw.Text("BUYER'S DETAILS TO BE FILLED IN CAPITAL LETTERS", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
        ),
        pw.SizedBox(height: 4),
        buyerRow('Name (Mr/Mrs/Ms)', d.buyerName, 'Passport No', d.buyerPassportNo),
        buyerRow('Address', d.buyerAddress, 'Date of Birth', d.buyerDOB != null ? dtFmt.format(d.buyerDOB!) : '—'),
        buyerRow('City', d.buyerCity, 'Nationality', d.buyerNationality),
        buyerRow('State', d.buyerState, 'Sea Port', d.buyerSeaPort),
        buyerRow('Zip Code', d.buyerZip, 'Country', d.buyerCountry),
        buyerRow('Cell No (Area code)', cell, 'E-mail', d.buyerEmail),
        buyerRow('WhatsApp No', d.buyerWhatsApp, '', ''),
        pw.SizedBox(height: 6),

        // Items table
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(36),
            1: pw.FlexColumnWidth(4),
            2: pw.FixedColumnWidth(50),
            3: pw.FixedColumnWidth(50),
            4: pw.FixedColumnWidth(80),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _th('Qnty'),
                _th('PARTICULARS\nHANDMADE HANDICRAFTS', center: false),
                _th('HSN\nCode'),
                _th('Size'),
                _th('Amount C.I.F.\nRs.            P.'),
              ],
            ),
            ...d.items.map((it) => pw.TableRow(children: [
                  _td(it.quantity.toString(), center: true),
                  _td(it.particulars),
                  _td(it.hsnCode ?? '—', center: true),
                  _td(it.size ?? '—', center: true),
                  _td(it.amountInr.toStringAsFixed(2), right: true),
                ])),
            // Pad up to ~10 rows to match printed form aesthetic
            ...List.generate(
              (10 - d.items.length).clamp(0, 10).toInt(),
              (_) => pw.TableRow(children: List.generate(5, (_) => _td(' '))),
            ),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _td(totalQty.toString(), center: true, bold: true),
                _td('Rs. in words: ${_amountInWords(total)}', bold: true),
                pw.SizedBox(),
                _td('TOTAL', center: true, bold: true),
                _td(total.toStringAsFixed(2), right: true, bold: true),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 8),
        pw.Text(
          '* Agreed to Terms & Condition Overleaf.\n'
          '* Goods reserved under this order can not be cancelled.\n'
          '* If Any Tax / Duties at the Destination will be paid by buyer.\n'
          '* No Exchange / No Refund of Goods Once Sold.',
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 12),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Buyer Signature', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 18),
            pw.Text('See Terms & Condition Over Leaf', style: const pw.TextStyle(fontSize: 7)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('For ${VoucherCompany.name}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 24),
            pw.Text('(Authorised Signatory)', style: const pw.TextStyle(fontSize: 8)),
          ]),
        ]),
      ],
    ),
  ));

  // ── Page 2: Instructions overleaf ──
  const tcs = [
    'Subject to Agra (India) Jurisdiction only',
    'No Exchange/ No Refund of Goods Once Sold.',
    'Goods dispatched by sea will be delivered at the nearest international sea-Port of the consignee. Name of the international Sea-Port will be given by the customer',
    "Transportation charges from Sea-port to customer's home and off loading charge will be borne by the customer.",
    'Custom made order will be dispatched on completion of order. The time for manufacture depends upon the labour involved, normally it takes 12 to 14 weeks for manufacture of the medium size table top.',
    'C.I.F. Means cost includes, Insurance from warehouse to warehouse and ocean freight upto Seaport.',
    'If Any Tax / Duties at the Destination will be Paid By Buyer.',
    'Once the shipment reached the destination custom clearance will be done by the buyer, if any delay in custom clearance the buyer will be solely responsible for the all charges occurred.',
    'If any loss or damage in transit Consignee will claim the insurance at the destination.',
    'In future correspondence please mention order number.',
  ];

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 60),
        pw.Center(child: pw.Text('INSTRUCTIONS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 30),
        ...List.generate(
          tcs.length,
          (i) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.SizedBox(width: 24, child: pw.Text('${i + 1}.', style: const pw.TextStyle(fontSize: 11))),
              pw.Expanded(child: pw.Text(tcs[i], style: const pw.TextStyle(fontSize: 11))),
            ]),
          ),
        ),
      ],
    ),
  ));

  return doc;
}

pw.Widget _th(String s, {bool center = true}) => pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        s,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );

pw.Widget _td(String s, {bool center = false, bool right = false, bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        s,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
        textAlign: center
            ? pw.TextAlign.center
            : right
                ? pw.TextAlign.right
                : pw.TextAlign.left,
      ),
    );
