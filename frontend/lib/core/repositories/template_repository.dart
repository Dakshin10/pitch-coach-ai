import 'package:flutter/foundation.dart';
import '../models/pitch_template.dart';
import '../services/api_client.dart';

class TemplateRepository {
  TemplateRepository();
  static final TemplateRepository instance = TemplateRepository();

  final _api = ApiClient.instance;
  List<PitchTemplate>? _cachedTemplates;

  static void setMockTemplates(List<PitchTemplate> list) {
    instance._cachedTemplates = list;
  }

  /// Returns available templates from the backend API, falling back to local defaults.
  Future<List<PitchTemplate>> getTemplates({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedTemplates != null && _cachedTemplates!.isNotEmpty) {
      return _cachedTemplates!;
    }

    try {
      final res = await _api.get('/templates');
      if (res is List) {
        final list = res
            .map((item) => PitchTemplate.fromJson(item as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          _cachedTemplates = list;
          return list;
        }
      }
    } catch (e) {
      debugPrint('[TemplateRepository] Failed to fetch templates from API: $e. Using local defaults.');
    }

    _cachedTemplates = PitchTemplate.defaultTemplates;
    return _cachedTemplates!;
  }

  /// Retrieves a specific template by ID.
  Future<PitchTemplate?> getTemplate(String templateId) async {
    final templates = await getTemplates();
    try {
      return templates.firstWhere(
        (t) => t.id.toLowerCase() == templateId.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
