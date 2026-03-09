import 'dart:math';

/// A pre-processed ayah entry kept in the sliding follow window.
class IndexedAyah {
  final int id;
  final int suraNo;
  final int ayaNo;
  final List<String> normTokens;
  const IndexedAyah({
    required this.id,
    required this.suraNo,
    required this.ayaNo,
    required this.normTokens,
  });
}

/// Result returned by [align].
class AlignResult {
  final int    ayahId;
  final double score;         // 0.0 – 1.0
  final int    matchedTokens; // how far into the ayah the transcript reached
  final int    totalTokens;   // total tokens in the matched ayah
  const AlignResult(this.ayahId, this.score, this.matchedTokens, this.totalTokens);
}

/// Greedy sequential token match.
///
/// Iterates [query] left-to-right; for each token finds the first occurrence
/// in [target] at or after the previous match position.  This respects word
/// order without requiring an exact contiguous match.
///
/// Score = matched / min(queryLen, [cap])  so short partial transcripts can
/// still score well if they match the beginning of an ayah.
double scoreTokens(List<String> query, List<String> target, {int cap = 12}) {
  if (query.isEmpty || target.isEmpty) return 0.0;
  int matched = 0;
  int ti = 0;
  for (final token in query) {
    while (ti < target.length && target[ti] != token) {
      ti++;
    }
    if (ti < target.length) {
      matched++;
      ti++;
    }
  }
  final denom = min(query.length, cap).toDouble();
  return matched / (denom < 1 ? 1 : denom);
}

/// Finds the best matching ayah for [rollingTokens] among [candidates].
///
/// Returns null when no candidate reaches [minScore].
/// [AlignResult.matchedTokens] is the position in the ayah token list after
/// the last successful match — a proxy for how far through the ayah the user
/// has read (used for intra-ayah word-level scroll positioning).
AlignResult? align(
  List<String> rollingTokens,
  List<IndexedAyah> candidates, {
  double minScore = 0.40,
}) {
  if (rollingTokens.isEmpty || candidates.isEmpty) return null;
  AlignResult? best;
  for (final c in candidates) {
    // Inline greedy match so we can capture the last-matched position.
    // `ti` is the forward scan cursor; `lastMatchedTi` is the position
    // after the last token that was actually found in the ayah.
    // We use `lastMatchedTi` (not `ti`) so that an unmatched trailing
    // transcript word doesn't push the cursor to the ayah end and give a
    // falsely-large progress value.
    int matched = 0;
    int ti = 0;
    int lastMatchedTi = 0;
    for (final token in rollingTokens) {
      while (ti < c.normTokens.length && c.normTokens[ti] != token) { ti++; }
      if (ti < c.normTokens.length) { matched++; ti++; lastMatchedTi = ti; }
    }
    final denom = min(rollingTokens.length, 12).toDouble();
    final score = matched / (denom < 1 ? 1 : denom);
    if (score >= minScore && (best == null || score > best.score)) {
      best = AlignResult(c.id, score, lastMatchedTi, c.normTokens.length);
    }
  }
  return best;
}
