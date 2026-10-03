enum ActivityType {
  story,
  letter,
  number,
  word,
  game;

  static ActivityType fromJson(Object? value) {
    if (value is String) {
      for (final type in values) {
        if (type.name == value) {
          return type;
        }
      }
    }
    throw FormatException('Invalid activity type.', value);
  }
}

class FlashcardContent {
  const FlashcardContent({
    required this.front,
    required this.back,
    this.audioAsset = '',
  });

  factory FlashcardContent.fromJson(Map<String, dynamic> json) {
    return FlashcardContent(
      front: _requiredString(json, 'front'),
      back: _requiredString(json, 'back'),
      audioAsset: _optionalString(json, 'audioAsset'),
    );
  }

  final String front;
  final String back;
  final String audioAsset;
}

class QuizContent {
  const QuizContent({
    required this.prompt,
    required this.options,
    required this.answerIndex,
    required this.hint,
  });

  factory QuizContent.fromJson(Map<String, dynamic> json) {
    final options = List<String>.unmodifiable(
      _requiredList(json, 'options').map(_stringValue),
    );
    final answerIndex = _requiredInt(json, 'answerIndex');
    if (options.isEmpty || answerIndex < 0 || answerIndex >= options.length) {
      throw const FormatException('Invalid quiz answer index.');
    }
    return QuizContent(
      prompt: _requiredString(json, 'prompt'),
      options: options,
      answerIndex: answerIndex,
      hint: _requiredString(json, 'hint'),
    );
  }

  final String prompt;
  final List<String> options;
  final int answerIndex;
  final String hint;
}

class ActivityContent {
  const ActivityContent({
    required this.id,
    required this.classId,
    required this.subjectId,
    required this.title,
    required this.activityType,
    this.story = '',
    this.flashcards = const <FlashcardContent>[],
    this.questions = const <QuizContent>[],
    this.practicePrompt = '',
    this.practiceHint = '',
    this.audioAsset = '',
    this.translations = const <String, Map<String, String>>{},
  });

  factory ActivityContent.fromJson(Map<String, dynamic> json) {
    final rawTranslations = _jsonMap(
      json['translations'] ?? const <String, dynamic>{},
      'translations',
    );
    final translations = <String, Map<String, String>>{};
    for (final entry in rawTranslations.entries) {
      final language = normalizeLanguageCode(entry.key);
      if (language == null) {
        throw FormatException(
            'Unsupported translation language code.', entry.key);
      }
      if (translations.containsKey(language)) {
        throw FormatException('Duplicate translation language.', entry.key);
      }
      translations[language] = Map<String, String>.unmodifiable({
        for (final value
            in _jsonMap(entry.value, 'translations.$language').entries)
          value.key:
              _stringValue(value.value, 'translations.$language.${value.key}'),
      });
    }
    return ActivityContent(
      id: _requiredString(json, 'id'),
      classId: _requiredString(json, 'classId'),
      subjectId: _requiredString(json, 'subjectId'),
      title: _requiredString(json, 'title'),
      activityType: ActivityType.fromJson(json['activityType']),
      story: _optionalString(json, 'story'),
      flashcards: List<FlashcardContent>.unmodifiable(
        _requiredList(json, 'flashcards').map(
          (value) => FlashcardContent.fromJson(
            _jsonMap(value, 'flashcards'),
          ),
        ),
      ),
      questions: List<QuizContent>.unmodifiable(
        _requiredList(json, 'questions').map(
          (value) => QuizContent.fromJson(_jsonMap(value, 'questions')),
        ),
      ),
      practicePrompt: _optionalString(json, 'practicePrompt'),
      practiceHint: _optionalString(json, 'practiceHint'),
      audioAsset: _optionalString(json, 'audioAsset'),
      translations: Map<String, Map<String, String>>.unmodifiable(translations),
    );
  }

  final String id;
  final String classId;
  final String subjectId;
  final String title;
  final ActivityType activityType;
  final String story;
  final List<FlashcardContent> flashcards;
  final List<QuizContent> questions;
  final String practicePrompt;
  final String practiceHint;
  final String audioAsset;
  final Map<String, Map<String, String>> translations;

  List<String> get availableLanguages {
    final languages = <String>{...translations.keys};
    return List<String>.unmodifiable(languages.toList()..sort());
  }

  bool hasLanguage(String language) {
    final code = normalizeLanguageCode(language);
    if (code == null) {
      return false;
    }
    return translations.containsKey(code);
  }

  ActivityText text(
    String? language, {
    required String sourceLanguage,
  }) {
    final source = normalizeLanguageCode(sourceLanguage) ??
        ContentCatalog.defaultSourceLanguage;
    final requested = normalizeLanguageCode(language ?? '');
    if (requested != null && requested != source) {
      final translation = translations[requested];
      if (translation != null) {
        final title = (translation['title'] ?? '').trim();
        final story = (translation['story'] ?? '').trim();
        if (title.isNotEmpty && story.isNotEmpty) {
          return ActivityText(
            language: requested,
            title: title,
            story: story,
            usedFallback: false,
          );
        }
      }
    }
    return ActivityText(
      language: source,
      title: title,
      story: story,
      usedFallback: requested != null && requested != source,
    );
  }
}

class ActivityText {
  const ActivityText({
    required this.language,
    required this.title,
    required this.story,
    required this.usedFallback,
  });

  final String language;
  final String title;
  final String story;
  final bool usedFallback;
}

class SubjectContent {
  const SubjectContent({
    required this.id,
    required this.title,
    this.subtitle = '',
  });

  factory SubjectContent.fromJson(Map<String, dynamic> json) {
    return SubjectContent(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      subtitle: _optionalString(json, 'subtitle'),
    );
  }

  final String id;
  final String title;
  final String subtitle;
}

class ContentCatalog {
  const ContentCatalog({
    this.version = 1,
    this.sourceLanguage = defaultSourceLanguage,
    this.translationLanguages = const <String>[],
    this.classIds = const <String>[],
    this.subjects = const <SubjectContent>[],
    this.activities = const <ActivityContent>[],
  });

  factory ContentCatalog.fromJson(Map<String, dynamic> json) {
    final versionValue = json['version'] ?? json['schemaVersion'];
    if (versionValue is! num || versionValue != versionValue.roundToDouble()) {
      throw const FormatException('Catalog version must be an integer.');
    }
    final sourceLanguageValue = json['sourceLanguage'] ?? defaultSourceLanguage;
    if (sourceLanguageValue is! String) {
      throw const FormatException('sourceLanguage must be a string.');
    }
    final sourceLanguage = normalizeLanguageCode(sourceLanguageValue);
    if (sourceLanguage == null) {
      throw FormatException(
        'sourceLanguage is not a supported language code.',
        sourceLanguageValue,
      );
    }
    return ContentCatalog(
      version: versionValue.toInt(),
      sourceLanguage: sourceLanguage,
      translationLanguages: List<String>.unmodifiable(
        _requiredList(json, 'translationLanguages').map(_stringValue),
      ),
      classIds: List<String>.unmodifiable(
        _requiredList(json, 'classIds').map(_stringValue),
      ),
      subjects: List<SubjectContent>.unmodifiable(
        _requiredList(json, 'subjects').map(
          (value) => SubjectContent.fromJson(_jsonMap(value, 'subjects')),
        ),
      ),
      activities: List<ActivityContent>.unmodifiable(
        _requiredList(json, 'activities').map(
          (value) => ActivityContent.fromJson(_jsonMap(value, 'activities')),
        ),
      ),
    );
  }

  static const String defaultSourceLanguage = 'en';

  final int version;
  final String sourceLanguage;
  final List<String> translationLanguages;
  final List<String> classIds;
  final List<SubjectContent> subjects;
  final List<ActivityContent> activities;

  List<String> get languages => List<String>.unmodifiable(<String>[
        sourceLanguage,
        ...translationLanguages,
      ]);

  bool supportsLanguage(String language) =>
      languages.contains(normalizeLanguageCode(language) ?? '');

  ActivityText textFor(ActivityContent activity, {String? language}) =>
      activity.text(language, sourceLanguage: sourceLanguage);
}

String? normalizeLanguageCode(String value) {
  final normalized = value.trim().replaceAll('_', '-').toLowerCase();
  if (!_languageCodePattern.hasMatch(normalized)) {
    return null;
  }
  return normalized;
}

final RegExp _languageCodePattern = RegExp(r'^[a-z]{2,3}(-[a-z]{2})?$');

Map<String, dynamic> _jsonMap(Object? value, String field) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, mapValue) {
        if (key is! String) {
          throw FormatException('$field contains a non-string key.');
        }
        return MapEntry(key, mapValue);
      },
    );
  }
  throw FormatException('$field must be an object.', value);
}

List<dynamic> _requiredList(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is List) {
    return value;
  }
  throw FormatException('$field must be a list.', value);
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String) {
    if (value.trim().isEmpty) {
      throw FormatException('$field must not be blank.', value);
    }
    return value;
  }
  throw FormatException('$field must be a string.', value);
}

String _optionalString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  throw FormatException('$field must be a string.', value);
}

int _requiredInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is int) {
    return value;
  }
  throw FormatException('$field must be an integer.', value);
}

String _stringValue(Object? value, [String field = 'value']) {
  if (value is String) {
    return value;
  }
  throw FormatException('$field must be a string.', value);
}
