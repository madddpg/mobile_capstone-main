import 'dart:convert';

import 'package:http/http.dart' as http;

class ProjectCategoryDto {
  final String id;
  final String name;
  final String? type;

  const ProjectCategoryDto({required this.id, required this.name, this.type});

  factory ProjectCategoryDto.fromJson(Map<String, dynamic> json) {
    return ProjectCategoryDto(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: json['type']?.toString(),
    );
  }
}

class MaterialsByCategoryDto {
  final String categoryId;
  final String categoryName;
  final List<Map<String, dynamic>> recommended;
  final List<Map<String, dynamic>> alternatives;

  const MaterialsByCategoryDto({
    required this.categoryId,
    required this.categoryName,
    required this.recommended,
    required this.alternatives,
  });

  factory MaterialsByCategoryDto.fromJson(Map<String, dynamic> json) {
    final recRaw = json['recommended'];
    final altRaw = json['alternatives'];

    return MaterialsByCategoryDto(
      categoryId: (json['category_id'] ?? '').toString(),
      categoryName: (json['category'] ?? '').toString(),
      recommended: (recRaw is List)
          ? recRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(growable: false)
          : const <Map<String, dynamic>>[],
      alternatives: (altRaw is List)
          ? altRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(growable: false)
          : const <Map<String, dynamic>>[],
    );
  }
}

/// HTTP client for the Firebase Functions materials catalog API.
class CloudMaterialsApi {
  final String baseUrl;
  final http.Client _client;

  CloudMaterialsApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  factory CloudMaterialsApi.forFirebaseFunctions({
    required String projectId,
    String region = 'us-central1',
    bool useEmulator = false,
    String? emulatorHost,
    int emulatorPort = 5001,
    http.Client? client,
  }) {
    if (useEmulator) {
      final host = (emulatorHost == null || emulatorHost.trim().isEmpty)
          ? 'localhost'
          : emulatorHost.trim();
      final url = 'http://$host:$emulatorPort/$projectId/$region/api';
      return CloudMaterialsApi(baseUrl: url, client: client);
    }

    final url = 'https://$region-$projectId.cloudfunctions.net/api';
    return CloudMaterialsApi(baseUrl: url, client: client);
  }

  Uri _uri(String path, Map<String, String> query) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalizedBase$path').replace(queryParameters: query);
  }

  String _describeBadResponse(http.Response res, Uri uri) {
    final body = res.body;

    String? backendError;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) {
        backendError = decoded['error'].toString();
      }
    } catch (_) {
      // Not JSON, ignore.
    }

    final snippet = body.trim().isEmpty
        ? null
        : body
              .trim()
              .replaceAll(RegExp(r'\s+'), ' ')
              .substring(
                0,
                body
                    .trim()
                    .replaceAll(RegExp(r'\s+'), ' ')
                    .length
                    .clamp(0, 240),
              );

    final details = backendError ?? snippet;
    return details == null || details.trim().isEmpty
        ? 'HTTP ${res.statusCode} for $uri'
        : 'HTTP ${res.statusCode} for $uri: $details';
  }

  Future<List<ProjectCategoryDto>> fetchCategories({
    required String project,
  }) async {
    final uri = _uri('/categories', {'project': project});
    final res = await _client.get(uri);

    if (res.statusCode != 200) {
      throw Exception(
        'Failed to fetch categories. ${_describeBadResponse(res, uri)}',
      );
    }

    final jsonBody = jsonDecode(res.body);
    final raw = (jsonBody is Map) ? jsonBody['categories'] : null;

    if (raw is! List) return const <ProjectCategoryDto>[];

    return raw
        .whereType<Map>()
        .map((e) => ProjectCategoryDto.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id.trim().isNotEmpty && e.name.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<MaterialsByCategoryDto> fetchMaterials({
    String? categoryId,
    String? categoryName,
    String? project,
  }) async {
    final query = <String, String>{};
    if (categoryId != null && categoryId.trim().isNotEmpty) {
      query['categoryId'] = categoryId.trim();
    }
    if (categoryName != null && categoryName.trim().isNotEmpty) {
      query['category'] = categoryName.trim();
    }
    if (project != null && project.trim().isNotEmpty) {
      query['project'] = project.trim();
    }

    final uri = _uri('/materials', query);
    final res = await _client.get(uri);

    if (res.statusCode != 200) {
      throw Exception(
        'Failed to fetch materials. ${_describeBadResponse(res, uri)}',
      );
    }

    final jsonBody = jsonDecode(res.body);
    if (jsonBody is! Map) {
      throw Exception('Invalid materials response.');
    }

    return MaterialsByCategoryDto.fromJson(Map<String, dynamic>.from(jsonBody));
  }
}
