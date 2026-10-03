class LegacyLittleLetter {
  const LegacyLittleLetter({
    required this.capital,
    required this.small,
    required this.word,
    required this.emoji,
    required this.hindi,
    required this.marathi,
  });

  final String capital;
  final String small;
  final String word;
  final String emoji;
  final String hindi;
  final String marathi;
}

class LegacyLittleNumber {
  const LegacyLittleNumber({
    required this.value,
    required this.word,
    required this.hindi,
    required this.marathi,
  });

  final int value;
  final String word;
  final String hindi;
  final String marathi;

  String get digits => '$value';
}

class LegacyLittleWord {
  const LegacyLittleWord({
    required this.word,
    required this.emoji,
    required this.hindi,
    required this.marathi,
  });

  final String word;
  final String emoji;
  final String hindi;
  final String marathi;

  List<String> get letters => word.split('');
}

abstract final class LegacyLittleCatalog {
  static const letters = <LegacyLittleLetter>[
    LegacyLittleLetter(
        capital: 'A',
        small: 'a',
        word: 'Apple',
        emoji: '\u{1F34E}',
        hindi: 'सेब',
        marathi: 'सफरचंद'),
    LegacyLittleLetter(
        capital: 'B',
        small: 'b',
        word: 'Ball',
        emoji: '⚽',
        hindi: 'गेंद',
        marathi: 'चेंडू'),
    LegacyLittleLetter(
        capital: 'C',
        small: 'c',
        word: 'Cat',
        emoji: '\u{1F431}',
        hindi: 'बिल्ली',
        marathi: 'मांजर'),
    LegacyLittleLetter(
        capital: 'D',
        small: 'd',
        word: 'Dog',
        emoji: '\u{1F436}',
        hindi: 'कुत्ता',
        marathi: 'कुत्रा'),
    LegacyLittleLetter(
        capital: 'E',
        small: 'e',
        word: 'Elephant',
        emoji: '\u{1F418}',
        hindi: 'हाथी',
        marathi: 'हत्ती'),
    LegacyLittleLetter(
        capital: 'F',
        small: 'f',
        word: 'Fish',
        emoji: '\u{1F41F}',
        hindi: 'मछली',
        marathi: 'मासा'),
    LegacyLittleLetter(
        capital: 'G',
        small: 'g',
        word: 'Grapes',
        emoji: '\u{1F347}',
        hindi: 'अंगूर',
        marathi: 'द्राक्ष'),
    LegacyLittleLetter(
        capital: 'H',
        small: 'h',
        word: 'Hat',
        emoji: '\u{1F3A9}',
        hindi: 'टोपी',
        marathi: 'टोपी'),
    LegacyLittleLetter(
        capital: 'I',
        small: 'i',
        word: 'Ice cream',
        emoji: '\u{1F366}',
        hindi: 'आइसक्रीम',
        marathi: 'आईस्क्रीम'),
    LegacyLittleLetter(
        capital: 'J',
        small: 'j',
        word: 'Juice',
        emoji: '\u{1F9C3}',
        hindi: 'जूस',
        marathi: 'रस'),
    LegacyLittleLetter(
        capital: 'K',
        small: 'k',
        word: 'Kite',
        emoji: '\u{1FA81}',
        hindi: 'पतंग',
        marathi: 'पतंग'),
    LegacyLittleLetter(
        capital: 'L',
        small: 'l',
        word: 'Lion',
        emoji: '\u{1F981}',
        hindi: 'शेर',
        marathi: 'सिंह'),
    LegacyLittleLetter(
        capital: 'M',
        small: 'm',
        word: 'Mango',
        emoji: '\u{1F96D}',
        hindi: 'आम',
        marathi: 'आंबा'),
    LegacyLittleLetter(
        capital: 'N',
        small: 'n',
        word: 'Nose',
        emoji: '\u{1F443}',
        hindi: 'नाक',
        marathi: 'नाक'),
    LegacyLittleLetter(
        capital: 'O',
        small: 'o',
        word: 'Owl',
        emoji: '\u{1F989}',
        hindi: 'उल्लू',
        marathi: 'घुबड'),
    LegacyLittleLetter(
        capital: 'P',
        small: 'p',
        word: 'Panda',
        emoji: '\u{1F43C}',
        hindi: 'पांडा',
        marathi: 'पांडा'),
    LegacyLittleLetter(
        capital: 'Q',
        small: 'q',
        word: 'Queen',
        emoji: '\u{1F478}',
        hindi: 'रानी',
        marathi: 'राणी'),
    LegacyLittleLetter(
        capital: 'R',
        small: 'r',
        word: 'Rabbit',
        emoji: '\u{1F430}',
        hindi: 'खरगोश',
        marathi: 'ससा'),
    LegacyLittleLetter(
        capital: 'S',
        small: 's',
        word: 'Sun',
        emoji: '☀️',
        hindi: 'सूरज',
        marathi: 'सूर्य'),
    LegacyLittleLetter(
        capital: 'T',
        small: 't',
        word: 'Tree',
        emoji: '\u{1F333}',
        hindi: 'पेड़',
        marathi: 'झाड'),
    LegacyLittleLetter(
        capital: 'U',
        small: 'u',
        word: 'Umbrella',
        emoji: '☔',
        hindi: 'छाता',
        marathi: 'छत्री'),
    LegacyLittleLetter(
        capital: 'V',
        small: 'v',
        word: 'Van',
        emoji: '\u{1F690}',
        hindi: 'वैन',
        marathi: 'व्हॅन'),
    LegacyLittleLetter(
        capital: 'W',
        small: 'w',
        word: 'Watermelon',
        emoji: '\u{1F349}',
        hindi: 'तरबूज',
        marathi: 'कलिंगड'),
    LegacyLittleLetter(
        capital: 'X',
        small: 'x',
        word: 'Xylophone',
        emoji: '\u{1F3B5}',
        hindi: 'संगीत वाद्य',
        marathi: 'वाद्य'),
    LegacyLittleLetter(
        capital: 'Y',
        small: 'y',
        word: 'Yacht',
        emoji: '⛵',
        hindi: 'नाव',
        marathi: 'बोट'),
    LegacyLittleLetter(
        capital: 'Z',
        small: 'z',
        word: 'Zebra',
        emoji: '\u{1F993}',
        hindi: 'ज़ेबरा',
        marathi: 'झेब्रा'),
  ];

  static const numbers = <LegacyLittleNumber>[
    LegacyLittleNumber(value: 1, word: 'One', hindi: 'एक', marathi: 'एक'),
    LegacyLittleNumber(value: 2, word: 'Two', hindi: 'दो', marathi: 'दोन'),
    LegacyLittleNumber(value: 3, word: 'Three', hindi: 'तीन', marathi: 'तीन'),
    LegacyLittleNumber(value: 4, word: 'Four', hindi: 'चार', marathi: 'चार'),
    LegacyLittleNumber(value: 5, word: 'Five', hindi: 'पाँच', marathi: 'पाच'),
    LegacyLittleNumber(value: 6, word: 'Six', hindi: 'छह', marathi: 'सहा'),
    LegacyLittleNumber(value: 7, word: 'Seven', hindi: 'सात', marathi: 'सात'),
    LegacyLittleNumber(value: 8, word: 'Eight', hindi: 'आठ', marathi: 'आठ'),
    LegacyLittleNumber(value: 9, word: 'Nine', hindi: 'नौ', marathi: 'नऊ'),
    LegacyLittleNumber(value: 10, word: 'Ten', hindi: 'दस', marathi: 'दहा'),
  ];

  static const words = <LegacyLittleWord>[
    LegacyLittleWord(
        word: 'CAT', emoji: '\u{1F431}', hindi: 'बिल्ली', marathi: 'मांजर'),
    LegacyLittleWord(
        word: 'DOG', emoji: '\u{1F436}', hindi: 'कुत्ता', marathi: 'कुत्रा'),
    LegacyLittleWord(word: 'SUN', emoji: '☀️', hindi: 'सूरज', marathi: 'सूर्य'),
    LegacyLittleWord(
        word: 'HAT', emoji: '\u{1F3A9}', hindi: 'टोपी', marathi: 'टोपी'),
    LegacyLittleWord(
        word: 'BAG', emoji: '\u{1F392}', hindi: 'बैग', marathi: 'पिशवी'),
    LegacyLittleWord(word: 'CUP', emoji: '☕', hindi: 'कप', marathi: 'कप'),
    LegacyLittleWord(word: 'PEN', emoji: '🖊️', hindi: 'कलम', marathi: 'पेन'),
    LegacyLittleWord(
        word: 'PIG', emoji: '\u{1F437}', hindi: 'सुअर', marathi: 'डुक्कर'),
    LegacyLittleWord(
        word: 'BUS', emoji: '\u{1F68C}', hindi: 'बस', marathi: 'बस'),
    LegacyLittleWord(
        word: 'RED', emoji: '\u{1F534}', hindi: 'लाल', marathi: 'लाल'),
  ];
}
