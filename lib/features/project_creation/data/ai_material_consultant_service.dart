import 'package:cloud_functions/cloud_functions.dart';

import 'package:iconstruct/features/project_creation/data/recommendation_cache.dart';

/// Result of one iConstruct AI consultation turn (Gemini/OpenAI via Cloud Functions).
class AiConsultResult {
  final bool success;
  final bool inScope;
  final String reply;
  final List<String> suggestions;
  final String? errorMessage;

  const AiConsultResult({
    required this.success,
    required this.inScope,
    required this.reply,
    required this.suggestions,
    this.errorMessage,
  });
}

/// One material the AI recommends from a builder's description.
class AiRecommendedMaterial {
  final String name;
  final String category;

  /// Why the job needs it, in a short phrase.
  final String reason;

  const AiRecommendedMaterial({
    required this.name,
    this.category = '',
    this.reason = '',
  });
}

class AiRecommendResult {
  final bool success;
  final List<AiRecommendedMaterial> materials;
  final String? errorMessage;

  const AiRecommendResult({
    required this.success,
    this.materials = const [],
    this.errorMessage,
  });
}

/// Calls Firebase Cloud Functions that proxy Gemini (iConstruct-scoped only).
class AiMaterialConsultantService {
  AiMaterialConsultantService({RecommendationCache? cache})
      : _cache = cache ?? RecommendationCache();

  final RecommendationCache _cache;

  /// The most recommendations shown; beyond this the list stops being a
  /// starting point and becomes a package nobody asked for.
  static const int maxRecommendations = 15;

  /// Recommends materials for [description], a builder's own account of the
  /// job, given the project and its renovation type.
  ///
  /// Uses `generateAIBOM` in recommend mode. A copy deployed before that mode
  /// existed ignores it and drafts a BOM from `additionalNotes`, which carries
  /// the same description, so this works on either version.
  Future<AiRecommendResult> recommend({
    required String projectType,
    required String scope,
    required String description,
  }) async {
    // A description already answered is answered again from the device. The
    // model is shared and returns 503 under load; a builder repeating a
    // question should not be at the mercy of that.
    final cached = await _cache.read(
      projectType: projectType,
      scope: scope,
      description: description,
    );
    if (cached != null) {
      return AiRecommendResult(success: true, materials: cached);
    }

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable(
        'generateAIBOM',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      final response = await callable.call(<String, dynamic>{
        'mode': 'recommend',
        'projectType': projectType,
        'scope': scope,
        'description': description,
        'style': 'As described by the builder',
        'additionalNotes':
            'Renovation type: $scope\nWhat the builder wants:\n$description',
      });

      final data = response.data;
      if (data is! Map) {
        return const AiRecommendResult(
          success: false,
          errorMessage: 'Unexpected AI response.',
        );
      }

      final materials = <AiRecommendedMaterial>[];
      final seen = <String>{};
      final raw = data['materials'];
      if (raw is List) {
        for (final entry in raw) {
          final map = entry is Map ? entry : const {};
          final name = (entry is Map ? map['name'] : entry)?.toString().trim() ?? '';
          if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
          materials.add(AiRecommendedMaterial(
            name: name,
            category: (map['category'] ?? '').toString().trim(),
            reason: (map['reason'] ?? '').toString().trim(),
          ));
          if (materials.length == maxRecommendations) break;
        }
      }

      if (materials.isEmpty) {
        // The server explains an off-topic description in its own words.
        final serverError = (data['error'] ?? '').toString().trim();
        return AiRecommendResult(
          success: false,
          errorMessage: serverError.isNotEmpty
              ? serverError
              : 'The AI did not recommend any materials. Describe the work in '
                  'more detail, or chat with the AI instead.',
        );
      }
      await _cache.write(
        projectType: projectType,
        scope: scope,
        description: description,
        materials: materials,
      );
      return AiRecommendResult(success: true, materials: materials);
    } on FirebaseFunctionsException catch (e) {
      return AiRecommendResult(success: false, errorMessage: _friendlyError(e));
    } catch (_) {
      return const AiRecommendResult(
        success: false,
        errorMessage: 'The AI service is unreachable right now.',
      );
    }
  }

  Future<AiConsultResult> consult({
    required String projectType,
    required String userMessage,
    String style = '',
    double areaSqm = 0,
    String? scope,
    List<String> ideaLog = const [],
    List<String> selectedMaterials = const [],
    String? projectNotes,
  }) async {
    final payload = <String, dynamic>{
      'projectType': projectType,
      'userMessage': userMessage,
      'style': style,
      'areaSqm': areaSqm,
      if (scope != null && scope.trim().isNotEmpty) 'scope': scope.trim(),
      'ideaLog': ideaLog,
      'selectedMaterials': selectedMaterials,
      if (projectNotes != null && projectNotes.trim().isNotEmpty)
        'projectNotes': projectNotes.trim(),
    };

    // Prefer dedicated function; fall back to generateAIBOM(mode: consult)
    // when consultAIMaterials is not deployed yet (NOT_FOUND).
    try {
      return await _call('consultAIMaterials', payload);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'NOT_FOUND') {
        try {
          return await _call('generateAIBOM', {
            ...payload,
            'mode': 'consult',
          });
        } on FirebaseFunctionsException catch (e2) {
          return AiConsultResult(
            success: false,
            inScope: true,
            reply: '',
            suggestions: const [],
            errorMessage: _friendlyError(e2),
          );
        }
      }
      return AiConsultResult(
        success: false,
        inScope: true,
        reply: '',
        suggestions: const [],
        errorMessage: _friendlyError(e),
      );
    } catch (e) {
      return const AiConsultResult(
        success: false,
        inScope: true,
        reply: '',
        suggestions: [],
        errorMessage: 'The AI service is unreachable right now.',
      );
    }
  }

  Future<AiConsultResult> _call(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable(
      functionName,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    final response = await callable.call(payload);
    final data = response.data;
    if (data is! Map) {
      return const AiConsultResult(
        success: false,
        inScope: true,
        reply: '',
        suggestions: [],
        errorMessage: 'Unexpected AI response.',
      );
    }

    final map = Map<String, dynamic>.from(data);
    final rawSuggestions = map['suggestions'];
    final suggestions = <String>[];
    if (rawSuggestions is List) {
      for (final s in rawSuggestions) {
        final name = s.toString().trim();
        if (name.isNotEmpty && !suggestions.contains(name)) {
          suggestions.add(name);
        }
      }
    }

    // Older BOM-only responses won't have reply/suggestions.
    if (map.containsKey('materials') && !map.containsKey('reply')) {
      return const AiConsultResult(
        success: false,
        inScope: true,
        reply: '',
        suggestions: [],
        errorMessage:
            'AI consult mode is not deployed yet. Redeploy Firebase Functions.',
      );
    }

    final hasReply = (map['reply'] ?? '').toString().trim().isNotEmpty;
    final ok = map['success'] == true || hasReply;

    return AiConsultResult(
      success: ok,
      inScope: map['inScope'] != false,
      reply: (map['reply'] ?? '').toString().trim(),
      suggestions: suggestions.take(8).toList(),
      errorMessage: ok
          ? null
          : (map['error']?.toString() ?? 'AI returned an empty response.'),
    );
  }

  String _friendlyError(FirebaseFunctionsException e) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();

    if (code == 'unauthenticated') {
      return 'Please sign in again to use iConstruct AI.';
    }
    if (code == 'not-found' ||
        message.contains('not_found') ||
        message.contains('not deployed')) {
      return 'The AI service is not deployed yet.';
    }
    // Only when the server says the key itself is missing. A retired or busy
    // model used to land here too, which sent builders to check a key that
    // was configured all along.
    if (code == 'failed-precondition' && message.contains('api key')) {
      return 'The AI key is not configured on the server.';
    }
    if (code == 'unavailable') {
      return 'The AI is busy right now. Try again in a moment, or start from '
          'a template instead.';
    }
    if (code == 'deadline-exceeded') {
      return 'The AI took too long to respond. Try again in a moment.';
    }
    if (code == 'resource-exhausted') {
      // The server says which limit was hit, when it resets, and that the
      // templates are still available. Replacing that with a vague line loses
      // the only part the builder can act on.
      final detail = (e.message ?? '').trim();
      return detail.isEmpty
          ? 'The AI is over its usage limit right now. Try again later.'
          : detail;
    }
    if (code == 'internal') {
      return 'The AI service hit an error. Try again in a moment.';
    }
    final m = (e.message ?? '').trim();
    return m.isEmpty ? 'The AI service is unavailable right now.' : m;
  }
}
