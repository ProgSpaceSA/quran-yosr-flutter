// Arabic text normalizer for Quran follow mode.
// Strips tashkeel, tatweel, punctuation and unifies letter variants so that
// ASR output and aya_text_emlaey can be compared on equal footing.

final _tashkeelRe = RegExp(
  r'[\u064B-\u065F'   // fathatan … sukun
  r'\u0610-\u061A'   // arabic sign sallallahou alayhe wasallam … small high qaf
  r'\u06D6-\u06DC'   // small high ligature sad with lam …
  r'\u06DF-\u06E4'   // small high rounded zero …
  r'\u06E7\u06E8'    // small high yeh, small high noon
  r'\u06EA-\u06ED]', // empty centre low stop …
);

final _tatweelRe   = RegExp(r'\u0640'); // kashida / tatweel
final _nonLetterRe = RegExp(            // everything that isn't an Arabic letter or space
  r'[^\u0600-\u06FF\u0750-\u077F\s]',
);

/// Normalises [text] into a form suitable for token matching.
///
/// Operations applied (order matters):
///   1. Remove tashkeel (diacritics)
///   2. Remove tatweel
///   3. Normalise alef variants → ا
///   4. Normalise alef wasla (ٱ) → ا
///   5. Normalise dotless ya (ى) → ي
///   6. Strip all non-Arabic-letter, non-space characters
///   7. Collapse runs of whitespace
String normalizeArabic(String text) {
  var s = text;
  s = s.replaceAll(_tashkeelRe, '');
  s = s.replaceAll(_tatweelRe, '');
  s = s.replaceAll(RegExp(r'[أإآ]'), 'ا');   // alef with hamza / madda
  s = s.replaceAll('\u0671', 'ا');             // alef wasla
  s = s.replaceAll('ى', 'ي');                 // alef maqsura → ya
  s = s.replaceAll(_nonLetterRe, ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

/// Splits [normalised] text into a list of non-empty word tokens.
List<String> tokenize(String normalised) =>
    normalised.split(' ').where((t) => t.isNotEmpty).toList();
