import 'dart:math';

class BleuScore {
  static const _charLevelLanguages = {
    'Japanese', 'Chinese', 'zh', 'ja', 'Chinese (Simplified)',
    'Chinese (Traditional)', 'zh-CN', 'zh-TW',
  };

  static List<String> _tokenize(String text, {String? language}) {
    final useChar =
        language != null && _charLevelLanguages.contains(language);

    if (useChar) {
      return text.runes
          .map((r) => String.fromCharCode(r))
          .where((c) => c.trim().isNotEmpty)
          .toList();
    }

    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s']"), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  static Map<String, int> _ngramCounts(List<String> tokens, int n) {
    final counts = <String, int>{};
    for (int i = 0; i <= tokens.length - n; i++) {
      final gram = tokens.sublist(i, i + n).join('\u200B');
      counts[gram] = (counts[gram] ?? 0) + 1;
    }
    return counts;
  }

  static double _modifiedPrecision(
    List<String> hypothesis,
    List<List<String>> references,
    int n,
  ) {
    if (hypothesis.length < n) return 0.0;
    final hypCounts = _ngramCounts(hypothesis, n);
    if (hypCounts.isEmpty) return 0.0;

    var match = 0;
    var total = 0;

    for (final entry in hypCounts.entries) {
      final gram = entry.key;
      final hCount = entry.value;
      final maxRef = references
          .map((r) => _ngramCounts(r, n)[gram] ?? 0)
          .fold(0, max);
      match += min(hCount, maxRef);
      total += hCount;
    }

    return total == 0 ? 0.0 : match / total;
  }

  static double _brevityPenalty(int hypLen, int refLen) {
    if (hypLen == 0) return 0.0;
    if (hypLen >= refLen) return 1.0;
    return exp(1.0 - refLen / hypLen);
  }

  static int _closestRefLen(List<List<String>> refTokensList, int hypLen) {
    return refTokensList
        .map((r) => r.length)
        .reduce((a, b) =>
            (a - hypLen).abs() <= (b - hypLen).abs() ? a : b);
  }

  static double sentenceBleu(
    String hypothesis,
    List<String> references, {
    int maxN = 4,
    String? language,
  }) {
    final hyp = _tokenize(hypothesis, language: language);
    final refs = references.map((r) => _tokenize(r, language: language)).toList();

    final hypLen = hyp.length;
    if (hypLen == 0 || refs.isEmpty) return 0.0;

    final effectiveMaxN = min(maxN, hypLen);
    if (effectiveMaxN <= 0) return 0.0;

    final refLen = _closestRefLen(refs, hypLen);

    double logSum = 0.0;
    for (int n = 1; n <= effectiveMaxN; n++) {
      final p = _modifiedPrecision(hyp, refs, n);
      if (p == 0.0) return 0.0;
      logSum += log(p);
    }

    return _brevityPenalty(hypLen, refLen) * exp(logSum / effectiveMaxN);
  }

  static double corpusBleu(
    List<String> hypotheses,
    List<List<String>> references, {
    int maxN = 4,
    String? language,
  }) {
    assert(
      hypotheses.length == references.length,
      'hypotheses and references must have the same length',
    );

    final matchCounts = List.filled(maxN, 0);
    final totalCounts = List.filled(maxN, 0);
    int totalHypLen = 0;
    int totalRefLen = 0;

    for (int i = 0; i < hypotheses.length; i++) {
      final hyp = _tokenize(hypotheses[i], language: language);
      final refs =
          references[i].map((r) => _tokenize(r, language: language)).toList();

      totalHypLen += hyp.length;
      totalRefLen += _closestRefLen(refs, hyp.length);

      for (int n = 1; n <= maxN; n++) {
        final hypCounts = _ngramCounts(hyp, n);
        for (final e in hypCounts.entries) {
          final maxRef =
              refs.map((r) => _ngramCounts(r, n)[e.key] ?? 0).fold(0, max);
          matchCounts[n - 1] += min(e.value, maxRef);
          totalCounts[n - 1] += e.value;
        }
      }
    }

    double logSum = 0.0;
    int effectiveOrders = 0;
    for (int n = 1; n <= maxN; n++) {
      if (totalCounts[n - 1] == 0) continue;
      if (matchCounts[n - 1] == 0) return 0.0;
      effectiveOrders++;
      logSum += log(matchCounts[n - 1] / totalCounts[n - 1]);
    }

    if (effectiveOrders == 0) return 0.0;

    return _brevityPenalty(totalHypLen, totalRefLen) *
        exp(logSum / effectiveOrders);
  }

  static String format(double score, {int decimals = 2}) =>
      (score * 100).toStringAsFixed(decimals);
}
