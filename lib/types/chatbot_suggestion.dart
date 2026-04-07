enum ChatbotSuggestion {
  explain(label: 'Explain', prompt: 'Explain this to me: '),
  synonyms(label: 'Synonyms', prompt: 'Give me synonyms for: '),
  travel(label: 'Travel', prompt: 'How do I say this while travelling: '),
  definition(label: 'Definition', prompt: 'Define the word: '),
  paraphrase(label: 'Paraphrase', prompt: 'Paraphrase the following: '),
  grammar(label: 'Grammar', prompt: 'Check the grammar of: '),
  translate(label: 'Translate', prompt: 'Translate to Chinese: '),
  example(label: 'Example', prompt: 'Give me example sentences for: '),
  pronunciation(label: 'Pronunciation', prompt: 'How do you pronounce this in English: ');

  const ChatbotSuggestion({required this.label, required this.prompt});

  final String label;
  final String prompt;

  static ChatbotSuggestion? tryFromName(String? name) {
    if (name == null) return null;
    try {
      return ChatbotSuggestion.values.byName(name);
    } catch (_) {
      return null;
    }
  }
}

