import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Company constants for the SK Cottage Industries voucher.
///
/// The customer-facing brand is "The Sangemarmar" (a unit of SK Cottage
/// Industries). The legal entity stamped at the bottom of the voucher is
/// SK Cottage Industries. GSTIN, IEC, bank, and SWIFT details all belong to
/// the legal entity.
class VoucherCompany {
  static const brandTop = 'The Sangemarmar';
  static const brandSub = 'A Unit of SK Cottage Industries';
  static const legalName = 'SK COTTAGE INDUSTRIES';
  static const tagline =
      'Manufacturers & Exporters of: Handmade Marble Inlay Handicrafts, Textiles, Embroidery & Jewelry';
  static const address =
      'E4/5B, E4/6B, TAJ NAGRI, PHASE II, AGRA - 282001, UTTAR PRADESH (INDIA)';
  static const phone = '9897063215';
  static const email = 'skcottage@yahoo.co.in';
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
  final String title; // 'EXPORT ORDER RECEIPT VOUCHER' or 'HAND DELIVERY VOUCHER'
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

Future<Uint8List> _loadLogoBytes() async {
  final data = await rootBundle.load('assets/images/logo.png');
  return data.buffer.asUint8List();
}

String _amountInWords(double amount) {
  const ones = [
    '', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE',
    'TEN', 'ELEVEN', 'TWELVE', 'THIRTEEN', 'FOURTEEN', 'FIFTEEN', 'SIXTEEN',
    'SEVENTEEN', 'EIGHTEEN', 'NINETEEN',
  ];
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

// ── Cell helpers ──────────────────────────────────────────────────────────
pw.Widget _th(String s, {pw.TextAlign align = pw.TextAlign.center, double size = 8.5}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        s,
        textAlign: align,
        style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold),
      ),
    );

pw.Widget _td(
  String s, {
  pw.TextAlign align = pw.TextAlign.left,
  bool bold = false,
  double size = 9,
}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        s,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

/// "Label .........value..........." style line used for buyer fields.
pw.Widget _fillLine(String label, String value, {double? labelWidth}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('$label ',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              )),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.only(left: 2, bottom: 1),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 0.4)),
              ),
              child: pw.Text(
                value,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    );

/// Two label/value pairs on one row.
pw.Widget _fillLine2(String l1, String v1, String l2, String v2,
        {int flex1 = 1, int flex2 = 1}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            flex: flex1,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('$l1 ',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.only(left: 2, bottom: 1),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 0.4)),
                    ),
                    child: pw.Text(v1, style: const pw.TextStyle(fontSize: 9)),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            flex: flex2,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('$l2 ',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.only(left: 2, bottom: 1),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 0.4)),
                    ),
                    child: pw.Text(v2, style: const pw.TextStyle(fontSize: 9)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

Future<pw.Document> buildVoucherPdf(VoucherData d) async {
  final logo = pw.MemoryImage(await _loadLogoBytes());
  final dtFmt = DateFormat('dd MMM yyyy');
  final total = d.items.fold(0.0, (s, i) => s + i.amountInr);
  final totalQty = d.items.fold(0, (s, i) => s + i.quantity);
  final cell = (d.buyerCellAreaCode != null && d.buyerCellAreaCode!.isNotEmpty) ||
          (d.buyerCellNo != null && d.buyerCellNo!.isNotEmpty)
      ? '${d.buyerCellAreaCode ?? ''} ${d.buyerCellNo ?? ''}'.trim()
      : '';

  final doc = pw.Document();

  // ── Page 1: voucher front ────────────────────────────────────────────────
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(22, 22, 22, 22),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ─── Top strip: GSTIN/IEC | TITLE | Cell/Email ────────────────────
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(3.5),
            2: pw.FlexColumnWidth(3),
          },
          children: [
            pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('GSTIN: ${VoucherCompany.gstin}',
                        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text('IEC: ${VoucherCompany.iec}',
                        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.Center(
                child: pw.Text(
                  d.title,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Cell : ${VoucherCompany.phone}',
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('e-mail : ${VoucherCompany.email}',
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ]),
          ],
        ),

        // ─── Company block: logo + brand + tagline + address ──────────────
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 52,
                height: 52,
                margin: const pw.EdgeInsets.only(right: 8),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      VoucherCompany.brandTop,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    pw.Text(VoucherCompany.brandSub,
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontStyle: pw.FontStyle.italic,
                        )),
                    pw.SizedBox(height: 2),
                    pw.Text(VoucherCompany.tagline,
                        style: const pw.TextStyle(fontSize: 8.5),
                        textAlign: pw.TextAlign.center),
                    pw.Text(VoucherCompany.address,
                        style: const pw.TextStyle(fontSize: 8.5),
                        textAlign: pw.TextAlign.center),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.Center(
          child: pw.Text(
            'BY SEA/AIR',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 4),

        // ─── Bank details (left) | Order meta (right) ─────────────────────
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(5),
            1: pw.FlexColumnWidth(4),
          },
          children: [
            pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.only(right: 10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bank Details:',
                        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text(VoucherCompany.bankName,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text(VoucherCompany.bankBranch,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('A/c No.: ${VoucherCompany.bankAccount}',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('IFSC: ${VoucherCompany.bankIfsc}',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('SWIFT Code: ${VoucherCompany.bankSwift}',
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.SizedBox(height: 6),
                  _fillLine('Order No.', d.orderNo),
                  pw.SizedBox(height: 4),
                  _fillLine('Date', dtFmt.format(d.orderDate.toLocal())),
                ],
              ),
            ]),
          ],
        ),
        pw.SizedBox(height: 6),

        // ─── Buyer's details section header ───────────────────────────────
        pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(width: 0.6),
              bottom: pw.BorderSide(width: 0.6),
            ),
          ),
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Center(
            child: pw.Text(
              "BUYER'S DETAILS TO BE FILLED IN CAPITAL LETTERS",
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.SizedBox(height: 4),

        // ─── Buyer fields (label + filled value or blank fill-in line) ────
        _fillLine('Name (Capital Letter) Mr./Mrs/Ms', d.buyerName),
        _fillLine2('Address (Capital Letters)', d.buyerAddress,
            'City', d.buyerCity, flex1: 3, flex2: 1),
        _fillLine2('State', d.buyerState, 'Zip Code', d.buyerZip),
        _fillLine('Country', d.buyerCountry),
        _fillLine2('Cell No. (Area code)', cell,
            'E-mail', d.buyerEmail, flex1: 1, flex2: 2),
        _fillLine2('Passport No', d.buyerPassportNo,
            'Date of Birth',
            d.buyerDOB != null ? dtFmt.format(d.buyerDOB!) : ''),
        _fillLine('Nationality', d.buyerNationality),
        _fillLine2('Sea Port', d.buyerSeaPort, 'WhatsApp No.', d.buyerWhatsApp),
        pw.SizedBox(height: 6),

        // ─── Items table ──────────────────────────────────────────────────
        _itemsTable(d.items),

        pw.SizedBox(height: 4),
        // ─── Total in words + Total amount ────────────────────────────────
        pw.Table(
          border: pw.TableBorder.all(width: 0.6),
          columnWidths: const {
            0: pw.FlexColumnWidth(7),
            1: pw.FlexColumnWidth(1.4),
            2: pw.FlexColumnWidth(2.2),
          },
          children: [
            pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: pw.Text(
                  'Rs. in words: ${total > 0 ? _amountInWords(total) : ''}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: pw.Center(
                  child: pw.Text('TOTAL',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: pw.Text(
                  total > 0 ? total.toStringAsFixed(2) : '',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ]),
          ],
        ),
        pw.SizedBox(height: 6),

        // ─── T&Cs (left) + "For [legal name]" (right) ─────────────────────
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(6),
            1: pw.FlexColumnWidth(4),
          },
          children: [
            pw.TableRow(children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('* Agreed to Terms & Condition Overleaf.',
                      style: const pw.TextStyle(fontSize: 8.5)),
                  pw.Text('* Goods reserved under this order can not be cancelled.',
                      style: const pw.TextStyle(fontSize: 8.5)),
                  pw.Text('* If Any Tax / Duties at the Destination will be paid by buyer.',
                      style: const pw.TextStyle(fontSize: 8.5)),
                  pw.Text('* No Exchange / No Refund of Goods Once Sold.',
                      style: const pw.TextStyle(fontSize: 8.5)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('For ${VoucherCompany.legalName}',
                      style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 26),
                  pw.Text('(Authorised Signatory)',
                      style: const pw.TextStyle(fontSize: 8.5)),
                ],
              ),
            ]),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Buyer Signature',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text('See Terms & Condition Over Leaf',
                style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic)),
          ],
        ),
        // Suppress unused-local warning when no items are present.
        if (totalQty == 0) pw.SizedBox(),
      ],
    ),
  ));

  // ── Page 2: instructions overleaf ────────────────────────────────────────
  const instructions = [
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
        pw.Center(
          child: pw.Text('INSTRUCTIONS',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 30),
        for (var i = 0; i < instructions.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 22,
                  child: pw.Text('${i + 1}.', style: const pw.TextStyle(fontSize: 11)),
                ),
                pw.Expanded(
                  child: pw.Text(instructions[i], style: const pw.TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
      ],
    ),
  ));

  return doc;
}

/// Items grid: Qnty | PARTICULARS HANDMADE HANDICRAFTS | HSN Code | Size |
/// Amount C.I.F. Rs. P. — pads to ~10 visible rows for the printed-form feel.
pw.Widget _itemsTable(List<VoucherItem> items) {
  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _th('Qnty.'),
        _th('PARTICULARS\nHANDMADE HANDICRAFTS', align: pw.TextAlign.center),
        _th('HSN\nCode'),
        _th('Size'),
        _th('Amount C.I.F.\nRs.            P.'),
      ],
    ),
  ];

  for (final it in items) {
    rows.add(pw.TableRow(children: [
      _td(it.quantity.toString(), align: pw.TextAlign.center),
      _td(it.particulars),
      _td(it.hsnCode ?? '', align: pw.TextAlign.center),
      _td(it.size ?? '', align: pw.TextAlign.center),
      _td(it.amountInr.toStringAsFixed(2), align: pw.TextAlign.right),
    ]));
  }

  // Pad to ~10 visible rows so the printed form looks consistent.
  final pad = (10 - items.length).clamp(0, 10);
  for (var i = 0; i < pad; i++) {
    rows.add(pw.TableRow(children: List.generate(5, (_) => _td(' '))));
  }

  return pw.Table(
    border: pw.TableBorder.all(width: 0.6),
    columnWidths: const {
      0: pw.FixedColumnWidth(40),
      1: pw.FlexColumnWidth(4.6),
      2: pw.FixedColumnWidth(48),
      3: pw.FixedColumnWidth(46),
      4: pw.FixedColumnWidth(90),
    },
    children: rows,
  );
}
