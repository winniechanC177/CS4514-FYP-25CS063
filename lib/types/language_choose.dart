enum LanguageChoose {
  english(label: 'English', sid: 3, shorten: 'en-us'),
  japanese(label: 'Japanese', sid: null, shorten: 'ja'),
  chineseSimplified(label: 'Chinese (Simplified)', sid: 45, shorten: 'zh'),
  chineseTraditional(label: 'Chinese (Traditional)', sid: 45, shorten: 'zh'),
  spanish(label: 'Spanish', sid: 28, shorten: 'es'),
  french(label: 'French', sid: 30, shorten: 'fr-fr'),
  hindi(label: 'Hindi', sid: 31, shorten: 'hi'),
  italian(label: 'Italian', sid: 35, shorten: 'it'),
  portuguese(label: 'Portuguese', sid: 42, shorten: 'pt-br');

  const LanguageChoose({
    required this.label,
    required this.sid,
    required this.shorten,
  });

  final String label;
  final int?   sid;
  final String shorten;

  bool get hasTtsSupport => sid != null;

  static LanguageChoose? tryParse(String? name) {
    if (name == null || name.isEmpty) return null;
    try {
      return LanguageChoose.values.byName(name);
    } catch (_) {}
    final lower = name.toLowerCase();
    if (lower == 'chinese') return LanguageChoose.chineseSimplified;
    try {
      return LanguageChoose.values.firstWhere(
        (l) => l.name.toLowerCase() == lower || l.label.toLowerCase() == lower,
      );
    } catch (_) {
      return null;
    }
  }
}
