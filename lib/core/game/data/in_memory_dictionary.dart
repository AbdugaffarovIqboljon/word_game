import '../domain/dictionary.dart';
import '../domain/logical_letter.dart';
import '../domain/word_tokenizer.dart';

/// A single seeded word plus its one-line definition.
class DictionaryEntry {
  const DictionaryEntry(this.word, this.definition);
  final String word;
  final String definition;
}

/// In-memory [Dictionary] used for v1 and for tests.
///
/// **Faked source:** the word list below is a small hand-curated seed. The real
/// dictionary (a bundled/validated Uzbek word list + a server-driven daily
/// answer schedule) is out of scope for this work package — see the phase
/// report. Every seeded answer tokenizes to exactly 5 logical letters.
class InMemoryDictionary implements Dictionary {
  InMemoryDictionary({List<DictionaryEntry>? entries})
    : _entries = entries ?? _seed {
    for (final entry in _entries) {
      final tokens = WordTokenizer.tokenize(entry.word);
      final key = WordTokenizer.keyOf(tokens);
      _tokensByKey[key] = tokens;
      _definitionByKey[key] = entry.definition;
      _answers.add(tokens);
    }
  }

  final List<DictionaryEntry> _entries;
  final Map<String, List<LogicalLetter>> _tokensByKey = {};
  final Map<String, String> _definitionByKey = {};
  final List<List<LogicalLetter>> _answers = [];

  /// Puzzle #1 falls on this date (UTC calendar).
  static final DateTime _epoch = DateTime.utc(2024, 1, 1);

  @override
  bool contains(List<LogicalLetter> word) =>
      _tokensByKey.containsKey(WordTokenizer.keyOf(word));

  @override
  List<LogicalLetter> answerForDate(DateTime date) {
    final index = _dayIndex(date) % _answers.length;
    return _answers[index];
  }

  @override
  String? definitionFor(List<LogicalLetter> word) =>
      _definitionByKey[WordTokenizer.keyOf(word)];

  @override
  int puzzleNumberForDate(DateTime date) => _dayIndex(date) + 1;

  /// Whole-calendar-day offset from [_epoch], timezone-independent.
  static int _dayIndex(DateTime date) {
    final dayUtc = DateTime.utc(date.year, date.month, date.day);
    final raw = dayUtc.difference(_epoch).inDays;
    return raw < 0 ? 0 : raw;
  }

  /// Curated seed. All words are 5 logical letters and cover every compound
  /// letter class (oʻ, gʻ, sh, ch).
  static const List<DictionaryEntry> _seed = [
    DictionaryEntry('qalam', 'Yozuv quroli'),
    DictionaryEntry('kitob', 'Oʻqish uchun asar'),
    DictionaryEntry('bahor', 'Yil fasllaridan biri'),
    DictionaryEntry('daryo', 'Katta suv oqimi'),
    DictionaryEntry('quyosh', 'Osmondagi yoritgich'),
    DictionaryEntry('shakar', 'Shirin oziq modda'),
    DictionaryEntry('salom', 'Koʻrishuv soʻzi'),
    DictionaryEntry('dunyo', 'Butun olam'),
    DictionaryEntry('chiroq', 'Yorugʻlik manbai'),
    DictionaryEntry('tuman', 'Quyuq nam havo'),
    DictionaryEntry('quloq', 'Eshitish aʼzosi'),
    DictionaryEntry('bodom', 'Magʻizli yongʻoq'),
    DictionaryEntry('tarix', 'Oʻtmish haqidagi fan'),
    DictionaryEntry('qorin', 'Oshqozon sohasi'),
    DictionaryEntry('soʻroq', 'Savol, soʻrash'),
    DictionaryEntry('oʻrmon', 'Zich daraxtzor'),
    DictionaryEntry('yigʻin', 'Odamlar majlisi'),
    DictionaryEntry('ogʻriq', 'Tanadagi azob'),
    DictionaryEntry('somon', 'Quruq poxol'),
    DictionaryEntry('paxta', 'Oq tolali oʻsimlik'),
    DictionaryEntry('osmon', 'Koʻk, samo'),
    DictionaryEntry('yomon', 'Yaxshining aksi'),
  ];
}
