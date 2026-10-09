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

  // The messages the builder sees, word for word as the functionality test
  // expects them. Kept in one place so the recommendation screen and the
  // chat cannot drift apart.

  /// No internet, or the AI service failed to answer.
  static const String unreachableMessage =
      'The AI service is unreachable right now.';

  /// What a builder can still do without the AI.
  static const String buildMyBomHint =
      'You can still tap “Build my BOM” and pick the work from the checklist '
      'yourself — quantities are estimated for you.';

  /// The AI answered but found no work in the catalogue for the description,
  /// including a description that is not about renovating at all.
  static const String noWorkPickedMessage =
      'The AI did not pick any work. Describe the work in more detail or '
      'start from the checklist instead.';

  /// The server has no AI key to call the model with.
  static const String keyNotConfiguredMessage =
      'The AI key is not configured on the server.';

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

      final result = workAnswer(response.data, catalogue);
      if (!result.success) return result;
      await _cache.write(
        projectType: cacheType,
        scope: scope,
        description: description,
        materials: [
          for (final pick in result.picks)
            AiRecommendedMaterial(name: pick.id, reason: pick.reason),
        ],
      );
      return result;
    } on FirebaseFunctionsException catch (e) {
      final message = friendlyError(e);
      return AiWorkRecommendResult(
        success: false,
        // The recommendation screen has a Build my BOM button, so say so.
        errorMessage: message == unreachableMessage
            ? '$unreachableMessage $buildMyBomHint'
            : message,
      );
    } catch (_) {
      return const AiWorkRecommendResult(
        success: false,
        errorMessage: '$unreachableMessage $buildMyBomHint',
      );
    }
  }

  /// What a recommend answer from the server comes to.
  static AiWorkRecommendResult workAnswer(
    Object? data,
    WorkCatalogue catalogue,
  ) {
    if (data is! Map) {
      // An answer the app cannot read is the AI service failing.
      return const AiWorkRecommendResult(
        success: false,
        errorMessage: '$unreachableMessage $buildMyBomHint',
      );
    }

    final picks = data.containsKey('workItems')
        ? workPicksFrom(data['workItems'], catalogue)
        : workPicksFromMaterials(data['materials'], catalogue);

    if (picks.isEmpty) {
      // One message whether the description was off-topic or simply named
      // no work in the catalogue. The server used to have its say on an
      // off-topic description ("I can only recommend work for a
      // renovation…"), so the builder saw a different message from the one
      // the screen documents for this case.
      return const AiWorkRecommendResult(
        success: false,
        errorMessage: noWorkPickedMessage,
      );
    }
    return AiWorkRecommendResult(success: true, picks: picks);
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
            errorMessage: friendlyError(e2),
          );
        }
      }
      return AiConsultResult(
        success: false,
        inScope: true,
        reply: '',
        suggestions: const [],
        errorMessage: friendlyError(e),
      );
    } catch (e) {
      return const AiConsultResult(
        success: false,
        inScope: true,
        reply: '',
        suggestions: [],
        errorMessage: unreachableMessage,
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

  /// The message for a failed AI call.
  ///
  /// No internet and an AI service that fails are one case to the builder,
  /// [unreachableMessage]. They used to read "The AI service hit an error"
  /// (no connection on Android arrives as `internal`), "The AI is busy right
  /// now… start from a template" (`unavailable`) or "took too long", none of
  /// which is the documented message.
  static String friendlyError(FirebaseFunctionsException e) {
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();

    if (code == 'unauthenticated') {
      return 'Please sign in again to use iConstruct AI.';
    }
    // Only when the server says the key itself is missing. A retired or busy
    // model used to land here too, which sent builders to check a key that
    // was configured all along. "GEMINI_API_KEY" is how an older copy of the
    // function names the missing key.
    if ((code == 'failed-precondition' || code == 'internal') &&
        (message.contains('api key') || message.contains('api_key'))) {
      return keyNotConfiguredMessage;
    }
    if (code == 'not-found' ||
        message.contains('not_found') ||
        message.contains('not deployed')) {
      return 'The AI service is not deployed yet.';
    }
    if (code == 'resource-exhausted') {
      // The server says which limit was hit, when it resets, and that the
      // checklist is still available. Replacing that with a vague line loses
      // the only part the builder can act on.
      final detail = (e.message ?? '').trim();
      return detail.isEmpty
          ? 'The AI is over its usage limit right now. Try again later.'
          : detail;
    }
    if (const {
      'unavailable',
      'internal',
      'deadline-exceeded',
      'unknown',
      'cancelled',
      'aborted',
      'data-loss',
    }.contains(code)) {
      return unreachableMessage;
    }
    final m = (e.message ?? '').trim();
    return m.isEmpty ? unreachableMessage : m;
  }
}
