import 'package:cloud_functions/cloud_functions.dart';

import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/recommendation_cache.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';

/// Result of one iConstruct AI consultation turn (Gemini/OpenAI via Cloud Functions).
class AiConsultResult {
  final bool success;
  final bool inScope;
  final String reply;
  final List<String> suggestions;

  /// Work item ids suggested from the catalogue sent with the message, when
  /// one was sent. Only ids in that catalogue.
  final List<String> suggestedWork;
  final String? errorMessage;

  const AiConsultResult({
    required this.success,
    required this.inScope,
    required this.reply,
    required this.suggestions,
    this.suggestedWork = const [],
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

/// One work item the AI picked from the project's catalogue.
class AiWorkPick {
  final String id;

  /// Why the description calls for it, in a short phrase.
  final String reason;

  const AiWorkPick({required this.id, this.reason = ''});
}

class AiWorkRecommendResult {
  final bool success;
  final List<AiWorkPick> picks;
  final String? errorMessage;

  const AiWorkRecommendResult({
    required this.success,
    this.picks = const [],
    this.errorMessage,
  });
}

/// Calls Firebase Cloud Functions that proxy Gemini (iConstruct-scoped only).
class AiMaterialConsultantService {
  AiMaterialConsultantService({RecommendationCache? cache})
      : _cache = cache ?? RecommendationCache();

  final RecommendationCache _cache;

  /// Recommends, from [catalogue], the work [description] calls for — a
  /// builder's own account of the job, given the project and its renovation
  /// type.
  ///
  /// The AI is shown the catalogue and answers with ids from it, so it can
  /// only pick work the app already has materials and formulas for. Anything
  /// it answers outside the catalogue is dropped.
  ///
  /// Uses `generateAIBOM` in recommend mode. A copy deployed before work items
  /// existed ignores them and recommends materials; those are matched to the
  /// work items that bring the same kinds of material, so this works on either
  /// version.
  Future<AiWorkRecommendResult> recommendWork({
    required String projectType,
    required String scope,
    required String description,
    required WorkCatalogue catalogue,
  }) async {
    // A description already answered is answered again from the device. The
    // model is shared and returns 503 under load; a builder repeating a
    // question should not be at the mercy of that. Work picks are kept apart
    // from any materials an older version cached for the same description.
    final cacheType = 'work|$projectType';
    final cached = await _cache.read(
      projectType: cacheType,
      scope: scope,
      description: description,
    );
    final cachedPicks = [
      for (final entry in cached ?? const <AiRecommendedMaterial>[])
        if (catalogue.byId(entry.name) != null)
          AiWorkPick(id: entry.name, reason: entry.reason),
    ];
    if (cachedPicks.isNotEmpty) {
      return AiWorkRecommendResult(success: true, picks: cachedPicks);
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
        'workItems': workItemsPayload(catalogue),
        'style': 'As described by the builder',
        'additionalNotes':
            'Renovation type: $scope\nWhat the builder wants:\n$description',
      });

      final data = response.data;
      if (data is! Map) {
        return const AiWorkRecommendResult(
          success: false,
          errorMessage: 'Unexpected AI response.',
        );
      }

      final picks = data.containsKey('workItems')
          ? workPicksFrom(data['workItems'], catalogue)
          : workPicksFromMaterials(data['materials'], catalogue);

      if (picks.isEmpty) {
        // The server explains an off-topic description in its own words.
        final serverError = (data['error'] ?? '').toString().trim();
        return AiWorkRecommendResult(
          success: false,
          errorMessage: serverError.isNotEmpty
              ? serverError
              : 'The AI did not pick any work. Describe the work in more '
                  'detail, or start from the checklist instead.',
        );
      }
      await _cache.write(
        projectType: cacheType,
        scope: scope,
        description: description,
        materials: [
          for (final pick in picks)
            AiRecommendedMaterial(name: pick.id, reason: pick.reason),
        ],
      );
      return AiWorkRecommendResult(success: true, picks: picks);
    } on FirebaseFunctionsException catch (e) {
      return AiWorkRecommendResult(
          success: false, errorMessage: _friendlyError(e));
    } catch (_) {
      return const AiWorkRecommendResult(
        success: false,
        errorMessage: 'The AI service is unreachable right now.',
      );
    }
  }

  /// The catalogue as the AI is shown it.
  static List<Map<String, String>> workItemsPayload(WorkCatalogue catalogue) =>
      [
        for (final item in catalogue.items)
          {
            'id': item.id,
            'label': item.label,
            'detail': item.detail,
            'kind': item.scope.label,
          },
      ];

  /// Work ids suggested in a chat answer. A server that predates work items
  /// suggests material names instead, which are matched to work by kind.
  static List<String> suggestedWorkFrom(
    Map<dynamic, dynamic> answer,
    WorkCatalogue catalogue,
  ) {
    final raw = answer['suggestedWork'];
    if (raw is List) {
      final seen = <String>{};
      return [
        for (final entry in raw)
          if (catalogue.byId('$entry'.trim()) != null &&
              seen.add('$entry'.trim()))
            '$entry'.trim(),
      ];
    }
    return [
      for (final pick in workPicksFromMaterials(answer['suggestions'], catalogue))
        pick.id,
    ];
  }

  /// The picks in a work answer that name an item in [catalogue], once each.
  static List<AiWorkPick> workPicksFrom(Object? raw, WorkCatalogue catalogue) {
    if (raw is! List) return const [];
    final seen = <String>{};
    return [
      for (final entry in raw)
        if (entry is Map &&
            catalogue.byId('${entry['id'] ?? ''}'.trim()) != null &&
            seen.add('${entry['id']}'.trim()))
          AiWorkPick(
            id: '${entry['id']}'.trim(),
            reason: '${entry['reason'] ?? ''}'.trim(),
          ),
    ];
  }

  /// Kinds too general to say which work a material belongs to.
  static const Set<MaterialKind> _vagueKinds = {
    MaterialKind.genericConsumable,
    MaterialKind.unknown,
  };

  /// Work items for a materials answer from a server that predates work
  /// items: each item whose materials include a recommended kind of material.
  /// The reason given is the first matching material's.
  static List<AiWorkPick> workPicksFromMaterials(
    Object? raw,
    WorkCatalogue catalogue,
  ) {
    if (raw is! List) return const [];
    final recommended = <MaterialKind, String>{};
    for (final entry in raw) {
      final name = (entry is Map ? entry['name'] : entry)?.toString() ?? '';
      if (name.trim().isEmpty) continue;
      final kind = classifyMaterialParts(
        name: name,
        category: entry is Map ? '${entry['category'] ?? ''}' : '',
      );
      if (_vagueKinds.contains(kind)) continue;
      recommended.putIfAbsent(
          kind, () => entry is Map ? '${entry['reason'] ?? ''}'.trim() : '');
    }
    return [
      for (final item in catalogue.items)
        for (final kind in {for (final m in item.materials) classifyMaterial(m)}
            .where(recommended.containsKey)
            .take(1))
          AiWorkPick(id: item.id, reason: recommended[kind]!),
    ];
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
    WorkCatalogue? catalogue,
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
      if (catalogue != null) 'workItems': workItemsPayload(catalogue),
    };

    // Prefer dedicated function; fall back to generateAIBOM(mode: consult)
    // when consultAIMaterials is not deployed yet (NOT_FOUND).
    try {
      return await _call('consultAIMaterials', payload, catalogue);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'NOT_FOUND') {
        try {
          return await _call(
              'generateAIBOM', {...payload, 'mode': 'consult'}, catalogue);
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
    Map<String, dynamic> payload, [
    WorkCatalogue? catalogue,
  ]) async {
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
      suggestedWork: catalogue == null
          ? const []
          : suggestedWorkFrom(map, catalogue),
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
