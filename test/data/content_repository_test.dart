import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_learning_app/core/errors/app_failure.dart';
import 'package:school_learning_app/data/content/content_models.dart';
import 'package:school_learning_app/data/content/content_repository.dart';

import '../support/legacy_little_catalog.dart';

const _catalogJson = '''
{
  "version": 1,
  "sourceLanguage": "en",
  "translationLanguages": ["hi"],
  "classIds": ["class-1"],
  "subjects": [
    {
      "id": "english",
      "title": "English",
      "subtitle": "Stories and words"
    }
  ],
  "activities": [
    {
      "id": "class-1-subject-english-activity-story",
      "classId": "class-1",
      "subjectId": "english",
      "title": "Hello, Friend",
      "activityType": "story",
      "story": "Ami says hello to the sun.",
      "flashcards": [
        {"front": "Hello", "back": "A friendly greeting"},
        {"front": "Goodbye", "back": "A kind way to leave"},
        {"front": "Thank you", "back": "We show kindness"}
      ],
      "questions": [
        {
          "prompt": "Which word is a greeting?",
          "options": ["Hello", "Chair", "Milk"],
          "answerIndex": 0,
          "hint": "Greetings are words we say when we meet."
        }
      ],
      "practicePrompt": "Trace and write: Hello",
      "practiceHint": "Say the word before writing it.",
      "audioAsset": "audio/lessons/lesson_english_c1.wav",
      "translations": {
        "hi": {
          "title": "नमस्ते, मित्र",
          "story": "अमी सूरज को नमस्ते कहती है।"
        }
      }
    }
  ]
}
''';

void main() {
  group('ContentRepository', () {
    test('loads activities and finds them by stable id', () async {
      final repository =
          ContentRepository(bundle: _CatalogBundle(_catalogJson));

      final catalog = await repository.load();
      final activity = repository.activityById(
        'class-1-subject-english-activity-story',
      );

      expect(catalog.activities, hasLength(1));
      expect(activity, isNotNull);
      expect(activity!.subjectId, 'english');
      expect(activity.translations['hi'], isNotEmpty);
      expect(
        activity.translations['hi']!['title'],
        'नमस्ते, मित्र',
      );
      expect(repository.activityById('missing'), isNull);
    });

    test('caches the loaded catalog and reads the asset once', () async {
      final bundle = _CatalogBundle(_catalogJson);
      final repository = ContentRepository(bundle: bundle);

      final firstLoad = await repository.load();
      final secondLoad = await repository.load();

      expect(identical(firstLoad, secondLoad), isTrue);
      expect(bundle.loadCount, 1);
    });

    test('rejects malformed JSON with invalid content failure', () async {
      final repository = ContentRepository(bundle: _CatalogBundle('{not-json'));

      await expectLater(
        repository.load(),
        throwsA(_isInvalidContentFailure),
      );
    });

    test('rejects an activity whose stable id fields disagree', () async {
      final source = _fixtureMap();
      final activity = (source['activities'] as List<dynamic>).single
          as Map<String, dynamic>;
      activity['id'] = 'class-2-subject-english-activity-story';
      final repository = ContentRepository(
        bundle: _CatalogBundle(jsonEncode(source)),
      );

      await expectLater(
        repository.load(),
        throwsA(_isInvalidContentFailure),
      );
    });

    test('rejects a blank primary activity title', () async {
      final source = _fixtureMap();
      final activity = (source['activities'] as List<dynamic>).single
          as Map<String, dynamic>;
      activity['title'] = '   ';
      final repository = ContentRepository(
        bundle: _CatalogBundle(jsonEncode(source)),
      );

      await expectLater(
        repository.load(),
        throwsA(_isInvalidContentFailure),
      );
    });

    test('rejects a blank story for story activities', () async {
      final source = _fixtureMap();
      final activity = (source['activities'] as List<dynamic>).single
          as Map<String, dynamic>;
      activity['story'] = '   ';
      final repository = ContentRepository(
        bundle: _CatalogBundle(jsonEncode(source)),
      );

      await expectLater(
        repository.load(),
        throwsA(_isInvalidContentFailure),
      );
    });

    test('allows empty story and audio for non-story activities', () async {
      final source = _fixtureMap();
      final activity = (source['activities'] as List<dynamic>).single
          as Map<String, dynamic>;
      activity['activityType'] = 'game';
      activity['story'] = '';
      activity['audioAsset'] = '';
      final repository = ContentRepository(
        bundle: _CatalogBundle(jsonEncode(source)),
      );

      final catalog = await repository.load();

      expect(catalog.activities.single.story, isEmpty);
      expect(catalog.activities.single.audioAsset, isEmpty);
    });

    test('rejects characters outside the stable id format', () async {
      final source = _fixtureMap();
      final activity = (source['activities'] as List<dynamic>).single
          as Map<String, dynamic>;
      activity['id'] = 'class-1-subject-english-activity-story with spaces';
      final repository = ContentRepository(
        bundle: _CatalogBundle(jsonEncode(source)),
      );

      await expectLater(
        repository.load(),
        throwsA(_isInvalidContentFailure),
      );
    });
  });

  test('content factories defensively copy mutable collections', () {
    final source = _fixtureMap();
    final sourceActivities = source['activities'] as List<dynamic>;
    final sourceActivity = sourceActivities.single as Map<String, dynamic>;
    final sourceFlashcards = sourceActivity['flashcards'] as List<dynamic>;
    final sourceQuestion = (sourceActivity['questions'] as List<dynamic>).single
        as Map<String, dynamic>;
    final sourceOptions = sourceQuestion['options'] as List<dynamic>;
    final sourceTranslations =
        sourceActivity['translations'] as Map<String, dynamic>;

    final catalog = ContentCatalog.fromJson(source);
    sourceActivities.clear();
    sourceFlashcards.clear();
    sourceOptions.clear();
    sourceTranslations.clear();

    expect(catalog.activities, hasLength(1));
    final activity = catalog.activities.single;
    expect(activity.flashcards, hasLength(3));
    expect(activity.questions.single.options, hasLength(3));
    expect(activity.translations, contains('hi'));
    expect(
      () => catalog.activities.add(activity),
      throwsUnsupportedError,
    );
    expect(
      () => activity.translations.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => activity.questions.single.options.add('Book'),
      throwsUnsupportedError,
    );
  });

  test('content factory rejects blank required strings', () {
    final source = _fixtureMap();
    final activity =
        (source['activities'] as List<dynamic>).single as Map<String, dynamic>;
    activity['title'] = '   ';

    expect(
      () => ContentCatalog.fromJson(source),
      throwsFormatException,
    );
  });

  test('Little Stars values exactly match the frozen legacy oracle', () {
    final catalog = _sharedCatalog();
    final activities = {
      for (final activity in catalog.activities) activity.id: activity,
    };
    final capitals = activities['class-0-subject-little-activity-capitals']!;
    final smalls = activities['class-0-subject-little-activity-smalls']!;
    final findLetter =
        activities['class-0-subject-little-activity-find-letter']!;
    final matchCase = activities['class-0-subject-little-activity-match-case']!;
    final numbers = activities['class-0-subject-little-activity-numbers']!;
    final firstWords =
        activities['class-0-subject-little-activity-first-words']!;

    expect(capitals.flashcards, hasLength(LegacyLittleCatalog.letters.length));
    expect(smalls.flashcards, hasLength(LegacyLittleCatalog.letters.length));
    expect(
        findLetter.flashcards, hasLength(LegacyLittleCatalog.letters.length));
    expect(matchCase.flashcards, hasLength(LegacyLittleCatalog.letters.length));
    expect(numbers.flashcards, hasLength(LegacyLittleCatalog.numbers.length));
    expect(firstWords.flashcards, hasLength(LegacyLittleCatalog.words.length));

    for (final (index, letter) in LegacyLittleCatalog.letters.indexed) {
      final expectedBack =
          '${letter.word} ${letter.emoji} | ${letter.hindi} | ${letter.marathi}';
      expect(capitals.flashcards[index].front,
          '${letter.capital} ${letter.small}');
      expect(capitals.flashcards[index].back, expectedBack);
      expect(
          smalls.flashcards[index].front, '${letter.small} ${letter.capital}');
      expect(smalls.flashcards[index].back, expectedBack);
      expect(findLetter.flashcards[index].front,
          '${letter.capital} ${letter.small}');
      expect(findLetter.flashcards[index].back, expectedBack);
      expect(matchCase.flashcards[index].front, letter.capital);
      expect(
        matchCase.flashcards[index].back,
        '${letter.small} | $expectedBack',
      );
    }

    for (final (index, number) in LegacyLittleCatalog.numbers.indexed) {
      expect(numbers.flashcards[index].front, '${number.value}');
      expect(
        numbers.flashcards[index].back,
        '${number.word} | ${number.hindi} | ${number.marathi}',
      );
    }

    for (final (index, word) in LegacyLittleCatalog.words.indexed) {
      expect(firstWords.flashcards[index].front, word.word);
      expect(
        firstWords.flashcards[index].back,
        '${word.word} ${word.emoji} | ${word.hindi} | ${word.marathi}',
      );
    }
  });

  group('language contract', () {
    test('language codes are normalised or rejected', () {
      expect(normalizeLanguageCode('en'), 'en');
      expect(normalizeLanguageCode(' EN '), 'en');
      expect(normalizeLanguageCode('hi'), 'hi');
      expect(normalizeLanguageCode('mr'), 'mr');
      expect(normalizeLanguageCode('pt_BR'), 'pt-br');
      expect(normalizeLanguageCode('english'), isNull);
      expect(normalizeLanguageCode(''), isNull);
      expect(normalizeLanguageCode('e'), isNull);
    });

    test('a requested translation resolves without a fallback flag', () {
      final catalog = _sharedCatalog();
      final activity = catalog.activities.firstWhere(
        (candidate) => candidate.hasLanguage('hi'),
      );

      final source =
          activity.text(null, sourceLanguage: catalog.sourceLanguage);
      final hindi = activity.text('hi', sourceLanguage: catalog.sourceLanguage);

      expect(source.language, 'en');
      expect(source.usedFallback, isFalse);
      expect(source.title, activity.title);
      expect(hindi.language, 'hi');
      expect(hindi.usedFallback, isFalse);
      expect(hindi.title, isNotEmpty);
      expect(hindi.story, isNotEmpty);
      expect(hindi.title, activity.translations['hi']!['title']);
      expect(hindi.story, activity.translations['hi']!['story']);
    });

    test('a requested translation actually changes the shipped text', () {
      final catalog = _sharedCatalog();

      final changed = catalog.activities.where((activity) {
        final hindi = activity.text('hi', sourceLanguage: 'en');
        return hindi.usedFallback ||
            hindi.title != activity.title ||
            hindi.story != activity.story;
      });
      final translatedHindi = catalog.activities
          .where((activity) => activity.hasLanguage('hi'))
          .length;

      expect(changed, isNotEmpty);
      expect(
        changed.length,
        greaterThanOrEqualTo(translatedHindi ~/ 2),
        reason: 'most Hindi lessons must differ from the English source',
      );
    });

    test('an untranslated language falls back to the source text', () {
      final catalog = _sharedCatalog();
      final activity = catalog.activities.firstWhere(
        (candidate) => !candidate.hasLanguage('mr'),
      );

      final fallback =
          activity.text('mr', sourceLanguage: catalog.sourceLanguage);

      expect(fallback.language, 'en');
      expect(fallback.usedFallback, isTrue);
      expect(fallback.title, activity.title);
      expect(fallback.story, activity.story);
    });

    test('the catalog reports its source and translation languages', () {
      final catalog = _sharedCatalog();

      expect(catalog.sourceLanguage, 'en');
      expect(catalog.translationLanguages, <String>['hi', 'mr']);
      expect(catalog.languages, <String>['en', 'hi', 'mr']);
      expect(catalog.supportsLanguage('hi'), isTrue);
      expect(catalog.supportsLanguage('HI'), isTrue);
      expect(catalog.supportsLanguage('mr'), isTrue);
      expect(catalog.supportsLanguage('ta'), isFalse);
    });

    test('catalog textFor mirrors the activity helper', () {
      final catalog = _sharedCatalog();
      final activity = catalog.activities.firstWhere(
        (candidate) => candidate.hasLanguage('hi'),
      );

      expect(
        catalog.textFor(activity, language: 'hi').title,
        activity.text('hi', sourceLanguage: 'en').title,
      );
    });

    test('every shipped activity keeps a translated title and story', () {
      final catalog = _sharedCatalog();

      for (final activity in catalog.activities) {
        expect(
          activity.availableLanguages,
          everyElement(isIn(<String>['en', 'hi', 'mr'])),
          reason: activity.id,
        );
        for (final entry in activity.translations.entries) {
          expect(entry.value['title'], isNotEmpty, reason: activity.id);
          expect(entry.value['story'], isNotEmpty, reason: activity.id);
        }
        if (activity.translations.containsKey('en')) {
          expect(activity.translations['en']!['title'], activity.title);
          expect(activity.translations['en']!['story'], activity.story);
        }
      }
    });

    test('shipped Hindi and Marathi lessons both stay reachable', () {
      final catalog = _sharedCatalog();

      for (final language in <String>['hi', 'mr']) {
        expect(
          catalog.activities
              .where((activity) => activity.hasLanguage(language)),
          isNotEmpty,
          reason: language,
        );
      }
      for (final activity in catalog.activities) {
        for (final language in <String>['hi', 'mr']) {
          final text = activity.text(language, sourceLanguage: 'en');
          expect(text.title, isNotEmpty, reason: '${activity.id} -> $language');
          expect(text.story, isNotEmpty, reason: '${activity.id} -> $language');
        }
      }
    });

    test('an undeclared translation language is rejected', () async {
      final fixture = _fixtureMap();
      (fixture['activities'] as List<dynamic>).first =
          ((fixture['activities'] as List<dynamic>).first
                  as Map<String, dynamic>)
              .cast<String, dynamic>()
            ..['translations'] = <String, dynamic>{
              'ta': <String, String>{'title': 'வணக்கம்', 'story': 'வணக்கம்'},
            };

      final repository =
          ContentRepository(bundle: _CatalogBundle(_encode(fixture)));

      await expectLater(repository.load(), throwsA(_isInvalidContentFailure));
    });

    test('a declared translation language must be used', () async {
      final fixture = _fixtureMap();
      fixture['translationLanguages'] = <String>['mr'];

      final repository =
          ContentRepository(bundle: _CatalogBundle(_encode(fixture)));

      await expectLater(repository.load(), throwsA(_isInvalidContentFailure));
    });

    test('the source language may not double as a translation language',
        () async {
      final fixture = _fixtureMap();
      fixture['translationLanguages'] = <String>['hi', 'en'];

      final repository =
          ContentRepository(bundle: _CatalogBundle(_encode(fixture)));

      await expectLater(repository.load(), throwsA(_isInvalidContentFailure));
    });

    test('translation languages must use normalized codes', () async {
      final fixture = _fixtureMap();
      fixture['translationLanguages'] = <String>['HI_in'];

      final repository =
          ContentRepository(bundle: _CatalogBundle(_encode(fixture)));

      await expectLater(repository.load(), throwsA(_isInvalidContentFailure));
    });

    test('a transient asset failure is not memoised by the bundle', () async {
      final bundle = _RepairableBundle(_encode(_fixtureMap()));
      final repository = ContentRepository(bundle: bundle);

      await expectLater(repository.load(), throwsA(_isInvalidContentFailure));

      bundle.repaired = true;

      final catalog = await repository.load();
      expect(catalog.activities, isNotEmpty);
      expect(bundle.loadCount, 2);
      expect(await repository.load(), same(catalog));
      expect(bundle.loadCount, 2);
    });
  });

  test('shared catalog preserves classes, lessons, games, and audio', () {
    final source = jsonDecode(
      File('assets/content/catalog.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final catalog = ContentCatalog.fromJson(source);
    final classActivities = catalog.activities
        .where((activity) => activity.subjectId != 'little')
        .toList();
    final littleActivities = catalog.activities
        .where((activity) => activity.subjectId == 'little')
        .toList();

    expect(
      catalog.classIds,
      containsAll(<String>[
        'class-1',
        'class-2',
        'class-3',
        'class-4',
        'class-5',
      ]),
    );
    expect(
      classActivities.map((activity) => activity.classId).toSet(),
      <String>{'class-1', 'class-2', 'class-3', 'class-4', 'class-5'},
    );
    expect(
      classActivities.map((activity) => activity.subjectId).toSet(),
      <String>{
        'english',
        'english_grammar',
        'marathi',
        'hindi',
        'mathematics',
        'evs',
        'computer',
        'gk',
        'communication',
      },
    );
    expect(classActivities, hasLength(45));
    for (final activity in classActivities) {
      expect(activity.id, matches(_stableIdPattern));
      expect(activity.flashcards, hasLength(3));
      expect(activity.questions, hasLength(3));
      expect(activity.practicePrompt, isNotEmpty);
      expect(activity.practiceHint, isNotEmpty);
      expect(activity.audioAsset, startsWith('audio/lessons/'));
      expect(File('assets/${activity.audioAsset}').existsSync(), isTrue);
      expect(activity.translations, isNotEmpty);
      for (final translation in activity.translations.values) {
        expect(translation['title'], isNotEmpty);
        expect(translation['story'], isNotEmpty);
      }
    }

    expect(
      littleActivities.map((activity) => activity.id).toSet(),
      <String>{
        'class-0-subject-little-activity-capitals',
        'class-0-subject-little-activity-smalls',
        'class-0-subject-little-activity-numbers',
        'class-0-subject-little-activity-find-letter',
        'class-0-subject-little-activity-match-case',
        'class-0-subject-little-activity-first-words',
      },
    );
    expect(littleActivities, hasLength(6));
  });
}

final Matcher _isInvalidContentFailure = isA<AppFailure>().having(
  (failure) => failure.code,
  'code',
  AppFailureCode.invalidContent,
);

final RegExp _stableIdPattern = RegExp(
  r'^class-\d+-subject-[a-z0-9_-]+-activity-[a-z0-9_-]+$',
);

ContentCatalog _sharedCatalog() {
  final source = jsonDecode(
    File('assets/content/catalog.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return ContentCatalog.fromJson(source);
}

Map<String, dynamic> _fixtureMap() =>
    (jsonDecode(_catalogJson) as Map<dynamic, dynamic>).cast<String, dynamic>();

String _encode(Map<String, dynamic> fixture) => jsonEncode(fixture);

class _RepairableBundle extends CachingAssetBundle {
  _RepairableBundle(this.contents);

  final String contents;
  bool repaired = false;
  int loadCount = 0;

  @override
  Future<ByteData> load(String key) async {
    loadCount += 1;
    if (key != 'assets/content/catalog.json') {
      throw StateError('Unexpected asset key: $key');
    }
    if (!repaired) {
      throw StateError('The learning shelf is still being unpacked.');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(contents)));
  }
}

class _CatalogBundle extends CachingAssetBundle {
  _CatalogBundle(this.contents);

  final String contents;
  int loadCount = 0;

  @override
  Future<ByteData> load(String key) async {
    loadCount += 1;
    if (key != 'assets/content/catalog.json') {
      throw StateError('Unexpected asset key: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(contents)));
  }
}
