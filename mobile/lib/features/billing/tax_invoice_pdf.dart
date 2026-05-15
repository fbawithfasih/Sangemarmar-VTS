import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'models/hand_delivery.dart';

/// Company constants for the SK Cottage Industries tax invoice.
/// The brand line ("The Sangemarmar — A Unit of SK Cottage Industries")
/// is what the customer sees; the legal entity on the invoice is SK Cottage
/// Industries (the GSTIN, address, bank details all belong to it).
class _Co {
  static const gstin = '09ADAPK6665Q1ZT';
  static const brandTop = 'The Sangemarmar';
  static const brandSub = 'A Unit of SK Cottage Industries';
  static const tagline =
      'Manufacturers & Exporters of: Handmade Marble Inlay Handicrafts, Textiles, Embroidery & Jewelry';
  static const address1 = 'E4/5B, E4/6B, TAJ NAGRI, PHASE II,';
  static const address2 = 'AGRA - 282001, UTTAR PRADESH (INDIA)';
  static const phone = '9897063215';
  static const email = 'skcottage@yahoo.co.in';
  static const bankName = 'IDBI BANK';
  static const bankBranch = 'IDBI BANK LTD, TAJGANJ, AGRA';
  static const bankAccount = '303102000000426';
  static const bankIfsc = 'IBKL0000303';
  static const legalName = 'SK COTTAGE INDUSTRIES';
  static const stateName = 'Uttar Pradesh';
  static const stateCode = '09';
}

Future<Uint8List> _loadLogoBytes() async {
  final data = await rootBundle.load('assets/images/logo.png');
  return data.buffer.asUint8List();
}

/// English-Indian (lakh/crore) number-to-words for the "Invoice Total in
/// words" line. Returns e.g. "FOUR THOUSAND RUPEES ONLY".
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

// ── Small helpers for table cells ─────────────────────────────────────────
pw.Widget _th(String s, {pw.TextAlign align = pw.TextAlign.center, double size = 8.5}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
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
  double size = 8.5,
}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        s,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

pw.Widget _labelValue(String label, String value, {bool bold = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 78,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );

Future<pw.Document> buildTaxInvoicePdf(HandDeliveryOrder o) async {
  final logo = pw.MemoryImage(await _loadLogoBytes());
  final dtFmt = DateFormat('dd-MM-yyyy');
  final igst = o.invoiceType == 'INTER_STATE';

  final fmt = NumberFormat('#,##0.00', 'en_IN');
  final cell = [o.buyerCellAreaCode ?? '', o.buyerCellNo ?? '']
      .where((s) => s.isNotEmpty)
      .join(' ');

  final taxable = o.totalTaxable;
  final gst = o.totalGst;
  final total = o.totalAmount;
  final cgst = gst / 2;
  final sgst = gst / 2;

  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(22, 22, 22, 22),
      build: (ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ─── Top strip: GSTIN (left) + TAX INVOICE (right) ────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'GSTIN: ${_Co.gstin}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
                pw.Text(
                  'TAX INVOICE',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),

            // ─── Company header (boxed) ──────────────────────────────────
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
              padding: const pw.EdgeInsets.all(8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 64,
                    height: 64,
                    margin: const pw.EdgeInsets.only(right: 10),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          _Co.brandTop,
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                        pw.Text(
                          _Co.brandSub,
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Container(
                          height: 0.5,
                          color: PdfColors.grey700,
                          margin: const pw.EdgeInsets.symmetric(horizontal: 40),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          _Co.tagline,
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontStyle: pw.FontStyle.italic,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          '${_Co.address1} ${_Co.address2}',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.Text(
                          'Phone: ${_Co.phone}    Email: ${_Co.email}',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── Buyer + Invoice meta (two columns) ──────────────────────
            // Use a Table here: pw.Row(stretch) with vertical-divider
            // Containers silently fails to lay out when its parent has no
            // bounded height, which collapses the rest of the page.
            pw.Table(
              border: pw.TableBorder(
                left: pw.BorderSide(width: 0.6),
                right: pw.BorderSide(width: 0.6),
                bottom: pw.BorderSide(width: 0.6),
                verticalInside: pw.BorderSide(width: 0.6),
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(6),
                1: pw.FlexColumnWidth(5),
              },
              children: [
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _labelValue('Name of Buyer', o.buyerName, bold: true),
                        _labelValue('Passport No./DOB', o.dobPassport ?? ''),
                        _labelValue('Country', (o.buyerCountry ?? '').toUpperCase()),
                        _labelValue('Email', o.buyerEmail ?? ''),
                        _labelValue('Contact', cell),
                        _labelValue('State Code', ''),
                        _labelValue('GSTIN', o.gstin ?? ''),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(width: 0.6)),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('State : ${_Co.stateName}',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.Text('State Code : ${_Co.stateCode}',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _labelValue('Reverse Charge', 'N.A.'),
                            _labelValue('Invoice No.', o.invoiceNumber, bold: true),
                            _labelValue('Invoice Date', dtFmt.format(o.orderDate.toLocal())),
                            _labelValue('Transportation Mode', ''),
                            _labelValue('Vehicle No.', ''),
                            _labelValue('Date of Supply', dtFmt.format(o.orderDate.toLocal())),
                            _labelValue('Place of Supply', ''),
                          ],
                        ),
                      ),
                    ],
                  ),
                ]),
              ],
            ),

            // ─── Items table ─────────────────────────────────────────────
            pw.SizedBox(height: 0),
            _itemsTable(o, igst, fmt),

            // ─── Footer block: bank/T&C on left, totals on right ─────────
            pw.SizedBox(height: 0),
            _footerBlock(
              taxable: taxable,
              cgst: igst ? null : cgst,
              sgst: igst ? null : sgst,
              igst: igst ? gst : null,
              total: total,
              totalWords: _amountInWords(total),
            ),

            // ─── Signatures ──────────────────────────────────────────────
            pw.Table(
              border: pw.TableBorder(
                left: pw.BorderSide(width: 0.6),
                right: pw.BorderSide(width: 0.6),
                bottom: pw.BorderSide(width: 0.6),
                verticalInside: pw.BorderSide(width: 0.6),
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(6),
                1: pw.FlexColumnWidth(5),
              },
              children: [
                pw.TableRow(children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Terms and Conditions',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '1. GOODS CHECKED, PACKED IN THE PRESENCE OF THE BUYER\n'
                          '   AND HAND CARRIED FOR PERSONAL USE.',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '2. ALL DISPUTES ARE SUBJECT TO AGRA JURISDICTION ONLY.',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          '3. NO REFUND / NO EXCHANGE ONCE GOODS SOLD.',
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                        pw.SizedBox(height: 22),
                        pw.Text('Signature of Buyer',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(10, 6, 8, 6),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Certified that the particulars given above are true and correct.',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'For, ${_Co.legalName}',
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 36),
                        pw.Text('Authorised Signatory',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ]),
              ],
            ),
          ],
        );
      },
    ),
  );

  return doc;
}

pw.Widget _itemsTable(HandDeliveryOrder o, bool igst, NumberFormat fmt) {
  // Column widths chosen to total roughly the printable width (~550pt at A4
  // with 22pt margins). IGST mode collapses CGST/SGST into one column.
  final cols = igst
      ? const <int, pw.TableColumnWidth>{
          0: pw.FixedColumnWidth(32),  // S.No.
          1: pw.FlexColumnWidth(4),    // Particulars
          2: pw.FixedColumnWidth(38),  // Size
          3: pw.FixedColumnWidth(40),  // HSN
          4: pw.FixedColumnWidth(30),  // Qty
          5: pw.FixedColumnWidth(56),  // Rate
          6: pw.FixedColumnWidth(64),  // Taxable Value
          7: pw.FixedColumnWidth(68),  // IGST
          8: pw.FixedColumnWidth(60),  // Total
        }
      : const <int, pw.TableColumnWidth>{
          0: pw.FixedColumnWidth(32),
          1: pw.FlexColumnWidth(4),
          2: pw.FixedColumnWidth(38),
          3: pw.FixedColumnWidth(40),
          4: pw.FixedColumnWidth(30),
          5: pw.FixedColumnWidth(54),
          6: pw.FixedColumnWidth(54),
          7: pw.FixedColumnWidth(48),  // CGST
          8: pw.FixedColumnWidth(48),  // SGST
          9: pw.FixedColumnWidth(54),  // Total
        };

  final headers = igst
      ? const ['S.No.', 'PARTICULARS', 'Size', 'HSN', 'Qty.', 'Rate', 'Taxable Value', 'IGST', 'Total']
      : const ['S.No.', 'PARTICULARS', 'Size', 'HSN', 'Qty.', 'Rate', 'Taxable Value', 'CGST', 'SGST', 'Total'];

  // Body rows — one per item; pad with blank rows so the table looks like the
  // reference form (~10 visible rows).
  final List<pw.TableRow> rows = [
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [for (final h in headers) _th(h)],
    ),
  ];

  for (var i = 0; i < o.items.length; i++) {
    final it = o.items[i];
    final rate = it.priceInr; // unit taxable price
    final taxable = it.taxableValue;
    final gst = it.gstAmount;
    final igstLabel = igst
        ? '${fmt.format(gst)} @${_trimRate(it.gstRate)}%'
        : null;

    rows.add(
      pw.TableRow(
        children: igst
            ? [
                _td('${i + 1}', align: pw.TextAlign.center),
                _td(it.particulars),
                _td(it.size ?? '', align: pw.TextAlign.center),
                _td(it.hsnCode ?? '', align: pw.TextAlign.center),
                _td('${it.quantity}', align: pw.TextAlign.center),
                _td(fmt.format(rate), align: pw.TextAlign.right),
                _td(fmt.format(taxable), align: pw.TextAlign.right),
                _td(igstLabel ?? '', align: pw.TextAlign.right),
                _td(fmt.format(it.amountInr), align: pw.TextAlign.right),
              ]
            : [
                _td('${i + 1}', align: pw.TextAlign.center),
                _td(it.particulars),
                _td(it.size ?? '', align: pw.TextAlign.center),
                _td(it.hsnCode ?? '', align: pw.TextAlign.center),
                _td('${it.quantity}', align: pw.TextAlign.center),
                _td(fmt.format(rate), align: pw.TextAlign.right),
                _td(fmt.format(taxable), align: pw.TextAlign.right),
                _td(fmt.format(gst / 2), align: pw.TextAlign.right),
                _td(fmt.format(gst / 2), align: pw.TextAlign.right),
                _td(fmt.format(it.amountInr), align: pw.TextAlign.right),
              ],
      ),
    );
  }

  // Filler rows so the table is a consistent height.
  final blanks = (10 - o.items.length).clamp(0, 10);
  for (var i = 0; i < blanks; i++) {
    rows.add(
      pw.TableRow(
        children: List.generate(headers.length, (_) => _td(' ')),
      ),
    );
  }

  // TOTAL row
  final totalQty = o.items.fold<int>(0, (s, i) => s + i.quantity);
  rows.add(
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      children: igst
          ? [
              _td('', align: pw.TextAlign.center, bold: true),
              _td('TOTAL', align: pw.TextAlign.right, bold: true),
              _td('', bold: true),
              _td('', bold: true),
              _td('$totalQty', align: pw.TextAlign.center, bold: true),
              _td('', bold: true),
              _td(fmt.format(o.totalTaxable), align: pw.TextAlign.right, bold: true),
              _td(fmt.format(o.totalGst), align: pw.TextAlign.right, bold: true),
              _td(fmt.format(o.totalAmount), align: pw.TextAlign.right, bold: true),
            ]
          : [
              _td('', align: pw.TextAlign.center, bold: true),
              _td('TOTAL', align: pw.TextAlign.right, bold: true),
              _td('', bold: true),
              _td('', bold: true),
              _td('$totalQty', align: pw.TextAlign.center, bold: true),
              _td('', bold: true),
              _td(fmt.format(o.totalTaxable), align: pw.TextAlign.right, bold: true),
              _td(fmt.format(o.totalGst / 2), align: pw.TextAlign.right, bold: true),
              _td(fmt.format(o.totalGst / 2), align: pw.TextAlign.right, bold: true),
              _td(fmt.format(o.totalAmount), align: pw.TextAlign.right, bold: true),
            ],
    ),
  );

  return pw.Table(
    border: pw.TableBorder.all(width: 0.6),
    columnWidths: cols,
    children: rows,
  );
}

/// Format the rate trimming trailing zeros: 5.0 → "5", 2.5 → "2.5".
String _trimRate(num rate) {
  final r = rate.toDouble();
  return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
}

pw.Widget _footerBlock({
  required double taxable,
  required double? cgst,
  required double? sgst,
  required double? igst,
  required double total,
  required String totalWords,
}) {
  pw.Widget kvRow(String label, String value, {bool bold = false}) => pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 0.4, color: PdfColors.grey)),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );

  final totalTax = (cgst ?? 0) + (sgst ?? 0) + (igst ?? 0);

  return pw.Table(
    border: pw.TableBorder(
      left: pw.BorderSide(width: 0.6),
      right: pw.BorderSide(width: 0.6),
      bottom: pw.BorderSide(width: 0.6),
      verticalInside: pw.BorderSide(width: 0.6),
    ),
    columnWidths: const {
      0: pw.FlexColumnWidth(6),
      1: pw.FlexColumnWidth(5),
    },
    children: [
      pw.TableRow(children: [
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('Invoice Total in words',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(totalWords,
                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text('Bank Details',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 2),
              _kvSmall('Bank Name', _Co.bankName),
              _kvSmall('Branch Name', _Co.bankBranch),
              _kvSmall('Bank Account Number', _Co.bankAccount),
              _kvSmall('Bank Branch IFSC', _Co.bankIfsc),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            kvRow('Taxable Amount', 'Rs ${_money(taxable)}'),
            kvRow('Add : CGST', cgst == null ? '-' : 'Rs ${_money(cgst)}'),
            kvRow('Add : SGST', sgst == null ? '-' : 'Rs ${_money(sgst)}'),
            kvRow('Add : IGST', igst == null ? '-' : 'Rs ${_money(igst)}'),
            kvRow('Total Tax', 'Rs ${_money(totalTax)}', bold: true),
            kvRow('Total Amount After Tax', 'Rs ${_money(total)}', bold: true),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('(E & O.E.)',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                      )),
                ],
              ),
            ),
            kvRow('GST Payable on Reverse Charge', 'N.A.'),
          ],
        ),
      ]),
    ],
  );
}

String _money(double v) =>
    NumberFormat('#,##0.00', 'en_IN').format(v);

pw.Widget _kvSmall(String k, String v) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(k, style: const pw.TextStyle(fontSize: 8.5)),
          ),
          pw.Expanded(
            child: pw.Text(v,
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
