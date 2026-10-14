import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/resume_interview.dart';
import '../services/api_client.dart';

class ResumeRepository {
  ResumeRepository();
  static final ResumeRepository instance = ResumeRepository();

  final _api = ApiClient.instance;

  /// Generates questions from an uploaded resume PDF or raw JD text.
  Future<ResumeQuestionsResult> generateQuestions({
    String? pdfPath,
    Uint8List? pdfBytes,
    String? pdfFileName,
    String? jdText,
    String? resumeText,
  }) async {
    final map = <String, dynamic>{};

    if (jdText != null && jdText.trim().isNotEmpty) {
      map['jd_text'] = jdText.trim();
    }
    if (resumeText != null && resumeText.trim().isNotEmpty) {
      map['resume_text'] = resumeText.trim();
    }

    if (pdfBytes != null) {
      map['resume_file'] = MultipartFile.fromBytes(
        pdfBytes,
        filename: pdfFileName ?? 'resume.pdf',
      );
    } else if (pdfPath != null) {
      if (kIsWeb) {
        throw StateError('File path upload is unsupported on web; provide bytes.');
      }
      map['resume_file'] = await MultipartFile.fromFile(
        pdfPath,
        filename: pdfFileName ?? 'resume.pdf',
      );
    }

    if (!map.containsKey('resume_file') &&
        !map.containsKey('resume_text') &&
        !map.containsKey('jd_text')) {
      throw ArgumentError('Please select a resume PDF or paste job description text.');
    }

    final formData = FormData.fromMap(map);

    try {
      final res = await _api.postMultipart(
        '/resume/generate-questions',
        formData,
      );
      if (res is Map<String, dynamic>) {
        return ResumeQuestionsResult.fromJson(res);
      }
      throw Exception('Unexpected server response format');
    } on DioException catch (e) {
      final serverDetail = e.response?.data is Map
          ? (e.response?.data as Map)['detail']?.toString()
          : null;
      if (serverDetail != null && serverDetail.isNotEmpty) {
        throw Exception(serverDetail);
      }
      rethrow;
    }
  }
}
