import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import 'api_client.dart';

/// Service for downloading and sharing branded PDF performance reports (Feature 10).
class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  final _api = ApiClient.instance;

  /// Downloads the session PDF report and saves it locally in the cache directory.
  Future<File?> downloadSessionReport(String sessionId) async {
    try {
      final res = await _api.dio.get<List<int>>(
        '/reports/sessions/$sessionId/pdf',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) return null;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pitch_coach_report_$sessionId.pdf');
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      debugPrint('[ReportService] Failed to download session report: $e');
      return null;
    }
  }

  /// Downloads the weekly progress PDF report and saves it locally.
  Future<File?> downloadWeeklyReport() async {
    try {
      final res = await _api.dio.get<List<int>>(
        '/reports/weekly/pdf',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) return null;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pitch_coach_weekly_report.pdf');
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      debugPrint('[ReportService] Failed to download weekly report: $e');
      return null;
    }
  }

  /// Opens or shares the session report using the system viewer or external browser.
  Future<bool> openOrShareSessionReport(String sessionId) async {
    try {
      final file = await downloadSessionReport(sessionId);
      if (file != null && await file.exists()) {
        final uri = Uri.file(file.path);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri);
        }
      }

      // Fallback: direct HTTP report URL
      final directUrl = Uri.parse('${AppConfig.apiBaseUrl}/reports/sessions/$sessionId/pdf');
      if (await canLaunchUrl(directUrl)) {
        return await launchUrl(directUrl, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      debugPrint('[ReportService] Error sharing session report: $e');
      return false;
    }
  }

  /// Opens or shares the weekly summary report.
  Future<bool> openOrShareWeeklyReport() async {
    try {
      final file = await downloadWeeklyReport();
      if (file != null && await file.exists()) {
        final uri = Uri.file(file.path);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri);
        }
      }

      final directUrl = Uri.parse('${AppConfig.apiBaseUrl}/reports/weekly/pdf');
      if (await canLaunchUrl(directUrl)) {
        return await launchUrl(directUrl, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      debugPrint('[ReportService] Error sharing weekly report: $e');
      return false;
    }
  }
}
