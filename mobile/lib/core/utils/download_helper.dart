import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import 'platform_file_saver.dart'
    if (dart.library.html) 'platform_file_saver_web.dart';

Future<void> downloadFile({
  required BuildContext context,
  required String path,
  required Map<String, dynamic> queryParams,
  required String filename,
}) async {
  final token = await ApiService().getToken();
  final url = '${ApiConstants.baseUrl}$path';

  try {
    final res = await Dio().get(
      url,
      queryParameters: queryParams,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.bytes,
      ),
    );

    final bytes = res.data as List<int>;
    if (context.mounted) {
      await saveAndOpenFile(context, bytes, filename);
    }
  } on DioException catch (e) {
    String msg = 'Download failed.';
    if (e.response != null) {
      msg = 'Server error ${e.response!.statusCode}. Try again.';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      msg = 'Request timed out. Check your connection.';
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.runtimeType}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

void showDownloadSheet({
  required BuildContext context,
  required String path,
  required Map<String, dynamic> queryParams,
  required String baseFilename,
}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Download As',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          _formatTile(
            context: context,
            icon: Icons.table_chart,
            label: 'Excel (.xlsx)',
            subtitle: 'Spreadsheet format',
            color: Colors.green,
            onTap: () {
              Navigator.pop(context);
              downloadFile(
                context: context,
                path: path,
                queryParams: {...queryParams, 'format': 'xlsx'},
                filename: '$baseFilename.xlsx',
              );
            },
          ),
          const SizedBox(height: 8),
          _formatTile(
            context: context,
            icon: Icons.picture_as_pdf,
            label: 'PDF (.pdf)',
            subtitle: 'Formatted report for printing',
            color: Colors.red,
            onTap: () {
              Navigator.pop(context);
              downloadFile(
                context: context,
                path: path,
                queryParams: {...queryParams, 'format': 'pdf'},
                filename: '$baseFilename.pdf',
              );
            },
          ),
        ],
      ),
    ),
  );
}

Widget _formatTile({
  required BuildContext context,
  required IconData icon,
  required String label,
  required String subtitle,
  required Color color,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Icon(Icons.download, color: color),
        ],
      ),
    ),
  );
}
