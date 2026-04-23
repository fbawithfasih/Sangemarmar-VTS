import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/download_helper.dart';
import '../../core/widgets/app_bar.dart';
import 'models/billing_order.dart';

class BillingDetailScreen extends StatefulWidget {
  final String orderId;
  const BillingDetailScreen({super.key, required this.orderId});

  @override
  State<BillingDetailScreen> createState() => _BillingDetailScreenState();
}

class _BillingDetailScreenState extends State<BillingDetailScreen> {
  final _api = ApiService();
  BillingOrder? _order;
  bool _loading = true;
  String? _error;
  final _dtFmt = DateFormat('dd MMM yyyy');
  final _fmtUsd = NumberFormat.currency(symbol: '\$ ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.get('${ApiConstants.billing}/${widget.orderId}');
      setState(() {
        _order = BillingOrder.fromJson(res.data as Map<String, dynamic>);
        _loading = false;
      });
    } catch (_) {
      setState(() { _error = 'Failed to load order'; _loading = false; });
    }
  }

  void _downloadOrv() {
    downloadFile(
      context: context,
      path: '${ApiConstants.billing}/${widget.orderId}/orv',
      queryParams: {},
      filename: 'orv_${widget.orderId.substring(0, 8)}.pdf',
    );
  }

  void _downloadInvoice() {
    downloadFile(
      context: context,
      path: '${ApiConstants.billing}/${widget.orderId}/invoice',
      queryParams: {},
      filename: 'invoice_${widget.orderId.substring(0, 8)}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SangemarmarAppBar(
        title: Text(_order?.invoiceNumber ?? 'Billing Order'),
        actions: _order == null
            ? []
            : [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.download),
                  onSelected: (v) {
                    if (v == 'orv') _downloadOrv();
                    if (v == 'invoice') _downloadInvoice();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'orv', child: ListTile(
                      leading: Icon(Icons.assignment, color: Color(0xFF1565C0)),
                      title: Text('Order Receipt Voucher'),
                      contentPadding: EdgeInsets.zero,
                    )),
                    PopupMenuItem(value: 'invoice', child: ListTile(
                      leading: Icon(Icons.receipt, color: Color(0xFF2E7D32)),
                      title: Text('Sales Invoice'),
                      contentPadding: EdgeInsets.zero,
                    )),
                  ],
                ),
                if (_order?.status == 'DRAFT')
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      await context.push('/billing/${widget.orderId}/edit');
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
    final vehicleNo = o.vehicleEntry?['vehicleNumber'] as String? ?? '—';
    final entryDate = o.vehicleEntry?['entryDate'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status + Invoice no
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
        const SizedBox(height: 16),

        // Vehicle entry card
        Card(
          color: const Color(0xFF1565C0).withOpacity(0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: const Color(0xFF1565C0).withOpacity(0.3)),
          ),
          child: ListTile(
            leading: const Icon(Icons.directions_car, color: Color(0xFF1565C0)),
            title: Text(vehicleNo, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(entryDate != null ? _dtFmt.format(DateTime.parse(entryDate).toLocal()) : ''),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          ),
        ),
        const SizedBox(height: 16),

        // Buyer details
        _card(
          title: "Buyer's Details",
          icon: Icons.person,
          color: const Color(0xFF2E7D32),
          child: Column(
            children: [
              _infoRow('Name', o.buyerName),
              _infoRow('Address', o.buyerAddress),
              _infoRow('City / State', '${o.buyerCity}, ${o.buyerState}'),
              _infoRow('Zip / Country', '${o.buyerZip}, ${o.buyerCountry}'),
              _infoRow('Passport No.', o.buyerPassportNo),
              _infoRow('Nationality', o.buyerNationality),
              if (o.buyerDOB != null) _infoRow('Date of Birth', _dtFmt.format(o.buyerDOB!)),
              _infoRow('Sea Port', o.buyerSeaPort),
              _infoRow('WhatsApp', o.buyerWhatsApp),
              _infoRow('E-mail', o.buyerEmail),
              if (o.notes != null && o.notes!.isNotEmpty) _infoRow('Notes', o.notes!),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Items
        _card(
          title: 'Items',
          icon: Icons.inventory_2,
          color: const Color(0xFFBF360C),
          child: Column(
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: const [
                    Expanded(flex: 4, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                    SizedBox(width: 8),
                    Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    SizedBox(width: 16),
                    SizedBox(width: 70, child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey), textAlign: TextAlign.right)),
                    SizedBox(width: 16),
                    SizedBox(width: 70, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey), textAlign: TextAlign.right)),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...o.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(flex: 4, child: Text(item.particulars, style: const TextStyle(fontSize: 13))),
                        const SizedBox(width: 8),
                        Text('${item.quantity}', style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 16),
                        SizedBox(width: 70, child: Text('\$ ${item.priceUsd.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                        const SizedBox(width: 16),
                        SizedBox(width: 70, child: Text('\$ ${item.amountUsd.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.right)),
                      ],
                    ),
                  )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('TOTAL  ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    _fmtUsd.format(o.totalUsd),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF6A1B9A)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Download buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.assignment),
                label: const Text('Download ORV'),
                onPressed: _downloadOrv,
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1565C0)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.receipt),
                label: const Text('Download Invoice'),
                onPressed: _downloadInvoice,
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2E7D32)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.local_shipping),
            label: const Text('Ship This Order'),
            onPressed: () => context.push(
              '/shipping/new',
              extra: {
                'billingOrderId': o.id,
                'buyer': {
                  'buyerName': o.buyerName,
                  'buyerAddress': o.buyerAddress,
                  'buyerCity': o.buyerCity,
                  'buyerState': o.buyerState,
                  'buyerZip': o.buyerZip,
                  'buyerCountry': o.buyerCountry,
                  'buyerWhatsApp': o.buyerWhatsApp,
                  'buyerEmail': o.buyerEmail,
                  'totalUsd': o.totalUsd,
                },
              },
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBF360C),
              minimumSize: const Size(0, 46),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

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
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
