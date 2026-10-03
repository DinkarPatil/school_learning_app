import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:school_learning_app/core/errors/app_failure.dart';
import 'package:school_learning_app/data/content/content_models.dart';

class ContentRepository {
  ContentRepository({
    required AssetBundle bundle,
    this.assetPath = 'assets/content/catalog.json',
  }) : _bundle = bundle;

  final AssetBundle _bundle;
  final String assetPath;
  ContentCatalog? _catalog;
  Map<String, ActivityContent>? _activitiesById;
  Future<ContentCatalog>? _loading;

  Future<ContentCatalog> load() {
    final catalog = _catalog;
    if (catalog != null) {
      return Future<ContentCatalog>.value(catalog);
    }
    return _loading ??= _load().whenComplete(() {
      _loading = null;
    });
  }

  ActivityContent? activityById(String id) => _activitiesById?[id];

  Future<ContentCatalog> _load() async {
    try {
      // `cache: false` keeps a failed read from being memoised by the asset
      // bundle, so the retry action can genuinely re-read the catalog.
      final source = await _bundle.loadString(assetPath, cache: false);
      final decoded = jsonDecode(source);
      if (decoded is! Map) {
        throw const FormatException('Catalog must be a JSON object.');
      }
      final catalog = ContentCatalog.fromJson(decoded.cast<String, dynamic>());
      _validate(catalog);
      _catalog = catalog;
      _activitiesById = {
        for (final activity in catalog.activities) activity.id: activity,
      };
      return catalog;
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure.invalidContent(cause: error);
    }
  }

  void _validate(ContentCatalog catalog) {
    if (catalog.version < 1) {
      throw const FormatException('Catalog version must be positive.');
    }
    if (catalog.classIds.isEmpty ||
        catalog.subjects.isEmpty ||
        catalog.activities.isEmpty) {
      throw const FormatException('Catalog content must not be empty.');
    }

    _validateLanguages(catalog);

    final classIds = <String>{};
    for (final classId in catalog.classIds) {
      if (!RegExp(r'^class-\d+$').hasMatch(classId) || !classIds.add(classId)) {
        throw FormatException('Invalid or duplicate class ID.', classId);
      }
    }

    final subjectIds = <String>{};
    for (final subject in catalog.subjects) {
      if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(subject.id) ||
          !subjectIds.add(subject.id)) {
        throw FormatException('Invalid or duplicate subject ID.', subject.id);
      }
    }

    final activityIds = <String>{};
    for (final activity in catalog.activities) {
      if (!activityIds.add(activity.id)) {
        throw FormatException('Duplicate activity ID.', activity.id);
      }
      if (activity.title.trim().isEmpty) {
        throw FormatException('Activity title must not be blank.', activity.id);
      }
      if (activity.activityType == ActivityType.story &&
          activity.story.trim().isEmpty) {
        throw FormatException(
            'Story activity text must not be blank.', activity.id);
      }
      if (!classIds.contains(activity.classId)) {
        throw FormatException('Unknown class ID.', activity.classId);
      }
      if (!subjectIds.contains(activity.subjectId)) {
        throw FormatException('Unknown subject ID.', activity.subjectId);
      }
      if (!RegExp(
        r'^class-\d+-subject-[a-z0-9_-]+-activity-[a-z0-9_-]+$',
      ).hasMatch(activity.id)) {
        throw FormatException('Invalid stable activity ID.', activity.id);
      }
      final classMatch = RegExp(r'^class-(\d+)$').firstMatch(activity.classId);
      final expectedPrefix =
          'class-${classMatch!.group(1)}-subject-${activity.subjectId}-activity-';
      if (!activity.id.startsWith(expectedPrefix) ||
          activity.id.length == expectedPrefix.length) {
        throw FormatException('Unstable activity ID.', activity.id);
      }
      if (activity.translations.isEmpty) {
        throw FormatException(
          'Activity translations must not be empty.',
          activity.id,
        );
      }
      for (final entry in activity.translations.entries) {
        if (!catalog.languages.contains(entry.key)) {
          throw FormatException(
            'Undeclared translation language.',
            '${activity.id} -> ${entry.key}',
          );
        }
        if ((entry.value['title'] ?? '').isEmpty ||
            (entry.value['story'] ?? '').isEmpty) {
          throw FormatException(
            'Activity translations require a title and story.',
            activity.id,
          );
        }
      }
    }
  }

  void _validateLanguages(ContentCatalog catalog) {
    final declared = <String>{};
    for (final language in catalog.translationLanguages) {
      if (normalizeLanguageCode(language) != language) {
        throw FormatException(
          'Translation languages must use normalized language codes.',
          language,
        );
      }
      if (language == catalog.sourceLanguage) {
        throw FormatException(
          'The source language must not also be a translation language.',
          language,
        );
      }
      if (!declared.add(language)) {
        throw FormatException('Duplicate translation language.', language);
      }
    }

    final used = <String>{};
    for (final activity in catalog.activities) {
      used.addAll(activity.translations.keys);
    }
    for (final language in declared) {
      if (!used.contains(language)) {
        throw FormatException(
          'A declared translation language has no translated content.',
          language,
        );
      }
    }
  }
}
