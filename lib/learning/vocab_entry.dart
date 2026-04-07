enum EntryType { vocab, grammar }

class VocabEntry {
  final String text;
  final String convText;
  final String lang;
  final String convLang;
  final String? example;
  final EntryType entryType;

  const VocabEntry({
    required this.text,
    required this.convText,
    required this.lang,
    required this.convLang,
    this.example,
    this.entryType = EntryType.vocab,
  });

  factory VocabEntry.fromMap(Map<String, dynamic> map) {
    final typeStr = map['EntryType'] as String?;
    return VocabEntry(
      text: (map['Text'] as String?) ?? '',
      convText: (map['ConvText'] as String?) ?? '',
      lang: (map['Lang'] as String?) ?? '',
      convLang: (map['ConvLang'] as String?) ?? '',
      example: map['Example'] as String?,
      entryType: typeStr == 'grammar' ? EntryType.grammar : EntryType.vocab,
    );
  }

  static List<VocabEntry> parseModelResponse(String response) {
    final result = <VocabEntry>[];
    for (final rawLine in response.split('\n')) {
      final line = rawLine
          .trim()
          .replaceFirst(RegExp(r'^\d+[.)]\s*'), '')
          .replaceFirst(RegExp(r'^[-*•]\s*'), '');
      if (!line.contains('|')) continue;
      final parts = line.split('|');
      if (parts.length < 2) continue;

      EntryType entryType = EntryType.vocab;
      List<String> data = parts;
      if (parts[0].trim().toUpperCase() == 'G') {
        entryType = EntryType.grammar;
        data = parts.sublist(1);
      } else if (parts[0].trim().toUpperCase() == 'V') {
        data = parts.sublist(1);
      }

      if (data.length < 2) continue;
      final text = data[0].trim();
      final convText = data[1].trim();
      final example = data.length >= 3 ? data[2].trim() : null;
      if (text.isNotEmpty && convText.isNotEmpty) {
        result.add(VocabEntry(
          text: text,
          convText: convText,
          example: example?.isNotEmpty == true ? example : null,
          lang: '',
          convLang: '',
          entryType: entryType,
        ));
      }
      if (result.length >= 10) break;
    }
    return result;
  }
}
