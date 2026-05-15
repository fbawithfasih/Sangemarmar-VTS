import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/widgets/app_bar.dart';
import 'models/hand_delivery.dart';
import 'voucher_pdf.dart';

class HandDeliveryDetailScreen extends StatefulWidget {
  final String orderId;
  const HandDeliveryDetailScreen({super.key, required this.orderId});

  @override
  State<HandDeliveryDetailScreen> createState() => _HandDeliveryDetailScreenState();
}

class _HandDeliveryDetailScreenState extends State<HandDeliveryDetailScreen> {
  final _api = ApiService();
  HandDeliveryOrder? _order;
  bool _loading = true;
  String? _error;
  final _dtFmt = DateFormat('dd MMM yyyy');
  final _fmtInr = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get('${ApiConstants.handDelivery}/${widget.orderId}');
      setState(() {
        _order = HandDeliveryOrder.fromJson(res.data as Map<String, dynamic>);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Failed to load hand delivery';
        _loading = false;
      });
    }
  }

  Future<void> _printVoucher() async {
    final o = _order;
    if (o == null) return;
    // The current voucher template still uses the legacy buyer fields. We pass
    // the slim-set fields where they map and leave the rest blank — PDF
    // redesign is scheduled as a follow-up.
    final data = VoucherData(
      title: 'HAND DELIVERY VOUCHER',
      orderNo: o.invoiceNumber,
      orderDate: o.orderDate,
      buyerName: o.buyerName,
      buyerAddress: '',
      buyerCity: '',
      buyerState: o.buyerState ?? '',
      buyerZip: '',
      buyerCountry: o.buyerCountry ?? '',
      buyerCellAreaCode: o.buyerCellAreaCode,
      buyerCellNo: o.buyerCellNo,
      buyerEmail: o.buyerEmail ?? '',
      buyerPassportNo: o.dobPassport ?? '',
      buyerDOB: null,
      buyerNationality: '',
      buyerSeaPort: '',
      buyerWhatsApp: '',
      items: o.items
          .map((i) => VoucherItem(
                quantity: i.quantity,
                particulars: i.particulars,
                hsnCode: i.hsnCode,
                size: i.size,
                amountInr: i.amountInr,
              ))
          .toList(),
    );
    final pdf = await buildVoucherPdf(data);
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'hand_delivery_${o.invoiceNumber}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SangemarmarAppBar(
        title: Text(_order?.invoiceNumber ?? 'Hand Delivery'),
        actions: _order == null
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: 'Print voucher (front + back)',
                  onPressed: _printVoucher,
                ),
                if (_order?.status == 'DRAFT')
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      await context.push('/billing/hand-delivery/${widget.orderId}/edit');
                      _load();
                    },
                  ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: _buildContent(),
                  ),
                ),
    );
  }

  Widget _buildContent() {
    final o = _order!;
    final igst = o.invoiceType == 'INTER_STATE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.invoiceNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(_dtFmt.format(o.orderDate.toLocal()), style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: o.status == 'CONFIRMED' ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: o.status == 'CONFIRMED' ? Colors.green.shade300 : Colors.orange.shade300),
              ),
              child: Text(
                o.status,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: o.status == 'CONFIRMED' ? Colors.green.shade700 : Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Invoice type badge ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(igst ? Icons.public : Icons.location_city, size: 14, color: const Color(0xFF1565C0)),
              const SizedBox(width: 6),
              Text(
                igst ? 'Inter State Invoice  •  IGST 5%' : 'Local Invoice  •  CGST 2.5% + SGST 2.5%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1565C0)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _card(
          title: "Buyer's Details",
          icon: Icons.person,
          color: const Color(0xFF2E7D32),
          child: Column(
            children: [
              _infoRow('Name', o.buyerName),
              if ((o.dobPassport ?? '').isNotEmpty) _infoRow('DOB / Passport', o.dobPassport!),
              if ((o.buyerState ?? '').isNotEmpty) _infoRow('State', o.buyerState!),
              if ((o.buyerCountry ?? '').isNotEmpty) _infoRow('Country', o.buyerCountry!),
              if ((o.gstin ?? '').isNotEmpty) _infoRow('GSTIN', o.gstin!),
              if ((o.buyerEmail ?? '').isNotEmpty) _infoRow('E-mail', o.buyerEmail!),
              if (((o.buyerCellAreaCode ?? '') + (o.buyerCellNo ?? '')).isNotEmpty)
                _infoRow('Cell No.', '${o.buyerCellAreaCode ?? ''} ${o.buyerCellNo ?? ''}'.trim()),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _card(
          title: 'Items',
          icon: Icons.inventory_2,
          color: const Color(0xFFBF360C),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: const [
                    Expanded(flex: 4, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                    SizedBox(width: 8),
                    Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    SizedBox(width: 12),
                    SizedBox(width: 70, child: Text('Taxable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey), textAlign: TextAlign.right)),
                    SizedBox(width: 12),
                    SizedBox(width: 60, child: Text('GST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey), textAlign: TextAlign.right)),
                    SizedBox(width: 12),
                    SizedBox(width: 70, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey), textAlign: TextAlign.right)),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...o.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.particulars, style: const TextStyle(fontSize: 13)),
                              if ((item.hsnCode ?? '').isNotEmpty || (item.size ?? '').isNotEmpty)
                                Text(
                                  'HSN: ${item.hsnCode ?? '—'}  •  Size: ${item.size ?? '—'}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${item.quantity}', style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 12),
                        SizedBox(width: 70, child: Text('₹ ${item.taxableValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                        const SizedBox(width: 12),
                        SizedBox(width: 60, child: Text('₹ ${item.gstAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                        const SizedBox(width: 12),
                        SizedBox(width: 70, child: Text('₹ ${item.amountInr.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.right)),
                      ],
                    ),
                  )),
              const Divider(),
              _summaryLine('Taxable Value', o.totalTaxable),
              if (igst)
                _summaryLine('IGST (5%)', o.totalGst)
              else ...[
                _summaryLine('CGST (2.5%)', o.totalGst / 2),
                _summaryLine('SGST (2.5%)', o.totalGst / 2),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('TOTAL  ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    _fmtInr.format(o.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7D32)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Print Voucher (Front + Back)'),
            onPressed: _printVoucher,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 46),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _summaryLine(String label, double value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('$label  ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            SizedBox(
              width: 90,
              child: Text('₹ ${value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right),
            ),
          ],
        ),
      );

  Widget _card({required String title, required IconData icon, required Color color, required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
