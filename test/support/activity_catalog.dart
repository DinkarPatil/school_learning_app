import 'dart:convert';

import 'package:flutter/services.dart';

AssetBundle activityCatalogBundle() => _CatalogBundle();

class _CatalogBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key != 'assets/content/catalog.json') {
      throw StateError('Unexpected asset key: $key');
    }
    return ByteData.sublistView(
      Uint8List.fromList(utf8.encode(activityCatalogJson())),
    );
  }
}

String activityCatalogJson() {
  final stories = <String>[];
  void addStory({
    required int level,
    required String subject,
    required String slug,
    required String title,
    required String practice,
  }) {
    stories.add('''
    {
      "id": "class-$level-subject-$subject-activity-$slug",
      "classId": "class-$level",
      "subjectId": "$subject",
      "title": "$title",
      "activityType": "story",
      "story": "Class $level reads and explores together.",
      "flashcards": [
        {"front": "Read", "back": "Look at words", "audioAsset": "audio/flashcards/flash_${subject}_1.wav"},
        {"front": "Write", "back": "Put it on paper"}
      ],
      "questions": [
        {"prompt": "Which word is a reading word?", "options": ["Read", "Run"], "answerIndex": 0, "hint": "Reading uses words."},
        {"prompt": "Which word is a writing word?", "options": ["Write", "Sing"], "answerIndex": 0, "hint": "Writing puts words on paper."}
      ],
      "practicePrompt": "$practice",
      "practiceHint": "Say it slowly.",
      "audioAsset": "audio/lessons/lesson_${subject}_c$level.wav",
      "translations": {"en": {"title": "$title", "story": "Class $level reads and explores together."}}
    }''');
  }

  addStory(
    level: 1,
    subject: 'english',
    slug: 'story',
    title: 'Class 1 Story',
    practice: 'Class 1 writes one word.',
  );
  addStory(
    level: 1,
    subject: 'english',
    slug: 'poem',
    title: 'Class 1 Poem',
    practice: 'Class 1 draws one word.',
  );
  addStory(
    level: 2,
    subject: 'english',
    slug: 'story',
    title: 'Class 2 Story',
    practice: 'Class 2 writes one word.',
  );
  addStory(
    level: 2,
    subject: 'mathematics',
    slug: 'story',
    title: 'Class 2 Sum',
    practice: 'Class 2 writes one sum.',
  );
  addStory(
    level: 3,
    subject: 'english',
    slug: 'story',
    title: 'Class 3 Story',
    practice: 'Class 3 writes one word.',
  );
  addStory(
    level: 4,
    subject: 'english',
    slug: 'story',
    title: 'Class 4 Story',
    practice: 'Class 4 writes one word.',
  );
  addStory(
    level: 5,
    subject: 'mathematics',
    slug: 'story',
    title: 'Class 5 Sum',
    practice: 'Class 5 writes one sum.',
  );

  final letters = <String>['A', 'B', 'C', 'D'];
  final letterCards = <String>[];
  for (final letter in letters) {
    letterCards.add(
      '{"front": "$letter ${letter.toLowerCase()}", '
      '"back": "${_word(letter)} \u{1F34E} | ${_hindi(letter)} | ${_marathi(letter)}"}',
    );
  }
  final matchCards = <String>[];
  for (final letter in letters) {
    matchCards.add(
      '{"front": "$letter", '
      '"back": "${letter.toLowerCase()} | ${_word(letter)} \u{1F34E} | ${_hindi(letter)} | ${_marathi(letter)}"}',
    );
  }
  final smallCards = <String>[];
  for (final letter in letters) {
    smallCards.add(
      '{"front": "${letter.toLowerCase()} $letter", '
      '"back": "${_word(letter)} \u{1F34E} | ${_hindi(letter)} | ${_marathi(letter)}"}',
    );
  }

  return '''{
  "version": 1,
  "sourceLanguage": "en",
  "translationLanguages": [],
  "classIds": ["class-0", "class-1", "class-2", "class-3", "class-4", "class-5"],
  "subjects": [
    {"id": "english", "title": "English", "subtitle": "Stories and words"},
    {"id": "mathematics", "title": "Mathematics", "subtitle": "Count and solve"},
    {"id": "little", "title": "Little Stars", "subtitle": "Letters, numbers, and gentle games"}
  ],
  "activities": [
    ${stories.join(',\n    ')},
    {
      "id": "class-0-subject-little-activity-capitals",
      "classId": "class-0",
      "subjectId": "little",
      "title": "Big ABC",
      "activityType": "letter",
      "story": "Meet every capital letter with its small letter friend.",
      "flashcards": [${letterCards.join(', ')}],
      "questions": [],
      "practicePrompt": "Point to each capital letter and say its name.",
      "practiceHint": "Take your time.",
      "audioAsset": "",
      "translations": {"en": {"title": "Big ABC", "story": "Meet every capital letter with its small letter friend."}}
    },
    {
      "id": "class-0-subject-little-activity-smalls",
      "classId": "class-0",
      "subjectId": "little",
      "title": "Small abc",
      "activityType": "letter",
      "story": "Practice every small letter beside its capital letter.",
      "flashcards": [${smallCards.join(', ')}],
      "questions": [],
      "practicePrompt": "Point to each small letter and say its name.",
      "practiceHint": "Take your time.",
      "audioAsset": "",
      "translations": {"en": {"title": "Small abc", "story": "Practice every small letter beside its capital letter."}}
    },
    {
      "id": "class-0-subject-little-activity-numbers",
      "classId": "class-0",
      "subjectId": "little",
      "title": "Numbers 1 to 10",
      "activityType": "number",
      "story": "Count slowly from one to ten.",
      "flashcards": [
        {"front": "1", "back": "One | \u090F\u0915 | \u090F\u0915"},
        {"front": "2", "back": "Two | \u0926\u094B | \u0926\u094B\u0928"},
        {"front": "3", "back": "Three | \u0924\u0940\u0928 | \u0924\u0940\u0928"},
        {"front": "4", "back": "Four | \u091A\u093E\u0930 | \u091A\u093E\u0930"},
        {"front": "5", "back": "Five | \u092A\u093E\u0901\u091A | \u092A\u093E\u091A"},
        {"front": "6", "back": "Six | \u091B\u0939 | \u0938\u0939\u093E"},
        {"front": "7", "back": "Seven | \u0938\u093E\u0924 | \u0938\u093E\u0924"},
        {"front": "8", "back": "Eight | \u0906\u0910 | \u0906\u0910"},
        {"front": "9", "back": "Nine | \u0928\u0909 | \u0928\u0909"},
        {"front": "10", "back": "Ten | \u0926\u0938 | \u0926\u0939\u093E"}
      ],
      "questions": [],
      "practicePrompt": "Count ten stars one at a time.",
      "practiceHint": "Touch each star as you count.",
      "audioAsset": "",
      "translations": {"en": {"title": "Numbers 1 to 10", "story": "Count slowly from one to ten."}}
    },
    {
      "id": "class-0-subject-little-activity-first-words",
      "classId": "class-0",
      "subjectId": "little",
      "title": "First Words",
      "activityType": "word",
      "story": "Read, hear, and match familiar animals and things.",
      "flashcards": [
        {"front": "CAT", "back": "CAT \u{1F431} | \u092C\u093F\u0932\u094D\u0932\u0940 | \u092E\u093E\u0902\u091C\u0930"},
        {"front": "DOG", "back": "DOG \u{1F436} | \u0915\u0941\u0924\u094D\u0924\u093E | \u0915\u0941\u0924\u094D\u0930\u093E"},
        {"front": "SUN", "back": "SUN \u2600\uFE0F | \u0938\u0942\u0930\u091C | \u0938\u0942\u0930\u094D\u092F"}
      ],
      "questions": [],
      "practicePrompt": "Point to each word and read it slowly.",
      "practiceHint": "Use the picture if you need a little help.",
      "audioAsset": "",
      "translations": {"en": {"title": "First Words", "story": "Read, hear, and match familiar animals and things."}}
    },
    {
      "id": "class-0-subject-little-activity-find-letter",
      "classId": "class-0",
      "subjectId": "little",
      "title": "Find the Letter",
      "activityType": "game",
      "story": "Find the requested capital and small letter among friendly choices.",
      "flashcards": [${letterCards.join(', ')}],
      "questions": [],
      "practicePrompt": "Choose the letter that the teacher asks for.",
      "practiceHint": "Look at both the big and small letter before choosing.",
      "audioAsset": "",
      "translations": {"en": {"title": "Find the Letter", "story": "Find the requested capital and small letter among friendly choices."}}
    },
    {
      "id": "class-0-subject-little-activity-match-case",
      "classId": "class-0",
      "subjectId": "little",
      "title": "Match Letters",
      "activityType": "game",
      "story": "Match every capital letter with its small letter friend.",
      "flashcards": [${matchCards.join(', ')}],
      "questions": [],
      "practicePrompt": "Draw a line from each capital letter to its small letter.",
      "practiceHint": "Say both letter names as you match them.",
      "audioAsset": "",
      "translations": {"en": {"title": "Match Letters", "story": "Match every capital letter with its small letter friend."}}
    }
  ]
}
''';
}

String _word(String letter) => const <String, String>{
      'A': 'Apple',
      'B': 'Ball',
      'C': 'Cat',
      'D': 'Dog',
    }[letter]!;

String _hindi(String letter) => const <String, String>{
      'A': '\u0938\u0947\u092C',
      'B': '\u0917\u0947\u0902\u0926',
      'C': '\u092C\u093F\u0932\u094D\u0932\u0940',
      'D': '\u0915\u0941\u0924\u094D\u0924\u093E',
    }[letter]!;

String _marathi(String letter) => const <String, String>{
      'A': '\u0938\u092B\u0930\u091A\u0902\u0926',
      'B': '\u091A\u0947\u0902\u0921\u0942',
      'C': '\u092E\u093E\u0902\u091C\u0930',
      'D': '\u0915\u0941\u0924\u094D\u0930\u093E',
    }[letter]!;
