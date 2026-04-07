import 'dart:async';
import 'package:flutter/material.dart';
import '../learning/learning.dart';
import '../learning/learning_vocab_block.dart';
import '../learning_Test/learning_test_block.dart';
import '../translation/translation.dart';
import '../chatbot/chatbot.dart';
import '../chatbot/chatbot_suggestions.dart';
import '../learning_Test/learning_test.dart';
import '../settings/settings.dart';
import '../database/database_helper.dart' as dbHelper;
import '../drawer/history_drawer.dart';
import '../model/model_response.dart';
import '../types/language_choose.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _history = [];
  int _selectedIndex = 0;
  final ModelResponse _modelResponse = ModelResponse();
  late final List<Widget> widgetOptions;
  final Map<int, int> _activeSessionId = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    widgetOptions = [
      Translation(
        onNewSession: _resetTranslationSession,
        onSendToChatbot: _openChatbotWithPrompt,
        onSessionCreated: (id) { setState(() => _activeSessionId[0] = id); _loadHistory(); },
      ),
      LearningTest(
        onSendToChatbot: _openChatbotWithPrompt,
        onSessionCreated: (id) { setState(() => _activeSessionId[1] = id); _loadHistory(); },
      ),
      Learning(
        onNewSession: _resetLearningSession,
        onSendToChatbot: _openChatbotWithPrompt,
        onSessionCreated: (id) { setState(() => _activeSessionId[2] = id); _loadHistory(); },
      ),
      Chatbot(
        onNewSession: _resetChatbotSession,
        onSessionCreated: (id) { setState(() => _activeSessionId[3] = id); _loadHistory(); },
      ),
      Settings(onDatabaseChanged: _resetAllSessions),
    ];
    unawaited(_modelResponse.switchContext(_contextKeyForIndex(_selectedIndex)));
    _loadHistory();
  }

  String _contextKeyForIndex(int index) {
    switch (index) {
      case 0:
        return 'translation';
      case 1:
        return 'testing';
      case 2:
        return 'learning';
      case 3:
        return 'chatbot';
      default:
        return 'settings';
    }
  }

  void _resetTranslationSession() {
    unawaited(_modelResponse.clearContext('translation',
        resetActiveChat: _selectedIndex == 0));
    setState(() {
      _activeSessionId.remove(0);
      widgetOptions[0] = Translation(
        key: UniqueKey(),
        onNewSession: _resetTranslationSession,
        onSendToChatbot: _openChatbotWithPrompt,
        onSessionCreated: (id) { setState(() => _activeSessionId[0] = id); _loadHistory(); },
      );
    });
  }

  Future<void> _openChatbotWithPrompt(String text,
      {ChatbotSuggestion? suggestion}) async {
    await _modelResponse.switchContext('chatbot');
    if (!mounted) return;
    setState(() {
      _selectedIndex = 3;
      _activeSessionId.remove(3);
      widgetOptions[3] = Chatbot(
        key: UniqueKey(),
        onNewSession: _resetChatbotSession,
        onSessionCreated: (id) { setState(() => _activeSessionId[3] = id); _loadHistory(); },
        initialQuery: text,
        initialSuggestion: suggestion,
      );
    });
  }

  Future<void> _resetChatbotSession() async {
    await _modelResponse.clearContext('chatbot', resetActiveChat: true);
    setState(() {
      _activeSessionId.remove(3);
      widgetOptions[3] = Chatbot(
        key: UniqueKey(),
        onNewSession: _resetChatbotSession,
        onSessionCreated: (id) { setState(() => _activeSessionId[3] = id); _loadHistory(); },
      );
    });
  }

  void _resetLearningSession() {
    setState(() {
      _activeSessionId.remove(2);
      widgetOptions[2] = Learning(
        key: UniqueKey(),
        onNewSession: _resetLearningSession,
        onSendToChatbot: _openChatbotWithPrompt,
        onSessionCreated: (id) { setState(() => _activeSessionId[2] = id); _loadHistory(); },
      );
    });
  }

  void _resetLearningTestSession() {
    setState(() {
      _activeSessionId.remove(1);
      widgetOptions[1] = LearningTest(
        key: UniqueKey(),
        onSendToChatbot: _openChatbotWithPrompt,
        onSessionCreated: (id) { setState(() => _activeSessionId[1] = id); _loadHistory(); },
      );
    });
  }

  LanguageChoose? _langFromString(String name) => LanguageChoose.tryParse(name);

  Future<void> _loadHistory() async {
    List<Map<String, dynamic>> result;
    switch (_selectedIndex) {
      case 0:
        result =
        await dbHelper.DatabaseHelper.instance.getAllTranslationSessions();
        break;
      case 1:
        result = await dbHelper.DatabaseHelper.instance.getLearningSessionsWithTestContent();
        break;
      case 2:
        result = await dbHelper.DatabaseHelper.instance.getAllLearningSessions();
        break;
      case 3:
        result = await dbHelper.DatabaseHelper.instance.getAllChatbotSessions();
        break;
      default:
        result = [];
    }
    setState(() {
      _history = result;
    });
  }

  Future<void> _loadSession(int sessionId) async {
    await _modelResponse.switchContext(_contextKeyForIndex(_selectedIndex));
    switch (_selectedIndex) {
      case 0:
        await _loadTranslationSession(sessionId);
        break;
      case 1:
        await _generateOrLoadTestFromLearningSession(sessionId);
        break;
      case 2:
        await _loadLearningSession(sessionId);
        break;
      case 3:
        await _loadChatbotSession(sessionId);
        break;
    }
  }

  Future<void> _loadTranslationSession(int sessionId) async {
    final items = await dbHelper.DatabaseHelper.instance
        .getTranslationSessionItems(sessionId);
    await _modelResponse.clearContext('translation', resetActiveChat: true);
    final memoryEntries = items
        .map(
          (item) => TranslationMemoryEntry(
            text: item['Text'] as String? ?? '',
            convText: item['ConvText'] as String? ?? '',
            language: item['Lang'] as String?,
            convLanguage: item['ConvLang'] as String? ?? 'Chinese',
          ),
        )
        .where((entry) =>
            entry.text.trim().isNotEmpty && entry.convText.trim().isNotEmpty)
        .toList();
    if (memoryEntries.isNotEmpty) {
      await _modelResponse.importTranslationMemoryEntries(
        memoryEntries,
        replaceExisting: true,
      );
    }
    setState(() {
      _activeSessionId[0] = sessionId;
      widgetOptions[0] = Translation(
        key: ValueKey<int>(sessionId),
        sessionId: sessionId,
        translationHistory: items,
        onNewSession: _resetTranslationSession,
        onSendToChatbot: _openChatbotWithPrompt,
      );
    });
  }

  Future<void> _loadChatbotSession(int sessionId) async {
    final items =
        await dbHelper.DatabaseHelper.instance.getChatbotSessionItems(sessionId);
    await _modelResponse.clearContext('chatbot', resetActiveChat: true);
    setState(() {
      _activeSessionId[3] = sessionId;
      widgetOptions[3] = Chatbot(
        key: ValueKey<int>(sessionId),
        sessionId: sessionId,
        chatbotHistory: items,
        onNewSession: _resetChatbotSession,
      );
    });
  }

  Future<void> _loadLearningSession(int sessionId) async {
    final items = await dbHelper.DatabaseHelper.instance
        .getLearningSessionItems(sessionId);
    final blocks = items.map((item) {
      final lang = _langFromString(item['Lang'] as String? ?? '')
          ?? LanguageChoose.english;
      final convLang = _langFromString(item['ConvLang'] as String? ?? '')
          ?? LanguageChoose.japanese;
      return LearningVocabBlock(
        key: ValueKey(item['LearningItemId']),
        blockId: item['LearningItemId'] as int,
        language: lang,
        convLanguage: convLang,
        text: item['Text'] as String? ?? '',
        convText: item['ConvText'] as String? ?? '',
        example: item['Example'] as String?,
      );
    }).toList();
    setState(() {
      _activeSessionId[2] = sessionId;
      widgetOptions[2] = Learning(
        key: ValueKey<int>(sessionId),
        learningBlocks: blocks,
        sessionId: sessionId,
        onNewSession: _resetLearningSession,
        onSendToChatbot: _openChatbotWithPrompt,
        onSessionCreated: (id) => setState(() => _activeSessionId[2] = id),
      );
    });
  }

  Future<void> _loadTestSession(int sessionId,
      {int? activeLearningSessionId}) async {
    final rows = await dbHelper.DatabaseHelper.instance
        .getFullTest(sessionId);
    final questionOrder = <int>[];
    final questionsMap = <int, String>{};
    final optionsMap = <int, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final id = row['TestItemID'] as int;
      if (!questionsMap.containsKey(id)) {
        questionOrder.add(id);
        questionsMap[id] = row['Question'] as String? ?? '';
        optionsMap[id] = [];
      }
      if (row['Option'] != null) {
        optionsMap[id]!.add({
          'option': row['Option'] as String,
          'isCorrect': (row['IsCorrect'] as int?) == 1,
        });
      }
    }
    final blocks = questionOrder.map((id) {
      final optList = optionsMap[id]!;
      final texts = optList.map((o) => o['option'] as String).toList();
      final correctIdx = optList.indexWhere((o) => o['isCorrect'] == true);
      return LearningTestBlock(
        key: ValueKey(id),
        blockId: id,
        question: questionsMap[id]!,
        options: texts,
        correctIndex: correctIdx >= 0 ? correctIdx : 0,
      );
    }).toList();
    setState(() {
      _activeSessionId[1] = activeLearningSessionId ?? sessionId;
      widgetOptions[1] = LearningTest(
        key: ValueKey<int>(sessionId),
        testBlocks: blocks,
        testSessionId: sessionId,
        sourceLearningSessionId: activeLearningSessionId,
        onSendToChatbot: _openChatbotWithPrompt,
        onSessionCreated: (id) => setState(() => _activeSessionId[1] = id),
      );
    });
  }
  Future<void> _deleteSession(int sessionId) async {
    switch (_selectedIndex) {
      case 0:
        await dbHelper.DatabaseHelper.instance.deleteSession(sessionId, 'translation');
        if (_activeSessionId[0] == sessionId) _resetTranslationSession();
        break;
      case 1:
        final linked = await dbHelper.DatabaseHelper.instance
            .getTestSessionByLearningSessionId(sessionId);
        if (linked != null) {
          await dbHelper.DatabaseHelper.instance
              .deleteSession(linked['TestSessionID'] as int, 'test');
        }
        if (_activeSessionId[1] == sessionId) _resetLearningTestSession();
        break;
      case 2:
        await dbHelper.DatabaseHelper.instance.deleteSession(sessionId, 'learning');
        if (_activeSessionId[2] == sessionId) _resetLearningSession();
        break;
      case 3:
        await dbHelper.DatabaseHelper.instance.deleteSession(sessionId, 'chatbot');
        if (_activeSessionId[3] == sessionId) unawaited(_resetChatbotSession());
        break;
    }
    _loadHistory();
  }
  Future<void> _generateOrLoadTestFromLearningSession(int learningSessionId) async {
    final db = dbHelper.DatabaseHelper.instance;
    final existing = await db.getTestSessionByLearningSessionId(learningSessionId);
    if (existing != null) {
      await _loadTestSession(
        existing['TestSessionID'] as int,
        activeLearningSessionId: learningSessionId,
      );
    } else {
      await _generateTestFromLearningSession(learningSessionId);
    }
  }

  Future<void> _generateTestFromLearningSession(int learningSessionId) async {
    final sessions =
        await dbHelper.DatabaseHelper.instance.getAllLearningSessions();
    final session = sessions.firstWhere(
      (s) => s['Id'] == learningSessionId,
      orElse: () => {'Title': 'Vocab Test'},
    );
    final title = session['Title']?.toString() ?? 'Vocab Test';

    setState(() {
      _selectedIndex = 1;
      widgetOptions[1] = LearningTest(
        key: UniqueKey(),
        autoGenerateFromSessionId: learningSessionId,
        autoGenerateTitle: title,
        onSendToChatbot: _openChatbotWithPrompt,
        onSessionCreated: (id) => setState(() => _activeSessionId[1] = id),
      );
    });
  }

  Future<void> _resetAllSessions() async {
    await _modelResponse.clearContext('translation', resetActiveChat: true);
    await _modelResponse.clearContext('chatbot', resetActiveChat: true);
    if (!mounted) return;
    setState(() {
      _activeSessionId.clear();
      widgetOptions[0] = Translation(
        key: UniqueKey(),
        onNewSession: _resetTranslationSession,
        onSendToChatbot: _openChatbotWithPrompt,
        onSessionCreated: (id) {
          setState(() => _activeSessionId[0] = id);
          _loadHistory();
        },
      );
      widgetOptions[1] = LearningTest(
        key: UniqueKey(),
        onSendToChatbot: _openChatbotWithPrompt,
        onSessionCreated: (id) {
          setState(() => _activeSessionId[1] = id);
          _loadHistory();
        },
      );
      widgetOptions[2] = Learning(
        key: UniqueKey(),
        onNewSession: _resetLearningSession,
        onSendToChatbot: _openChatbotWithPrompt,
        onSessionCreated: (id) {
          setState(() => _activeSessionId[2] = id);
          _loadHistory();
        },
      );
      widgetOptions[3] = Chatbot(
        key: UniqueKey(),
        onNewSession: _resetChatbotSession,
        onSessionCreated: (id) {
          setState(() => _activeSessionId[3] = id);
          _loadHistory();
        },
      );
    });
    _loadHistory();
  }

  Future<void> _deleteAllSession() async {
    switch (_selectedIndex) {
      case 0:
        await dbHelper.DatabaseHelper.instance.deleteAllSessions('translation');
        _resetTranslationSession();
        break;
      case 1:
        await dbHelper.DatabaseHelper.instance.deleteAllSessions('test');
        _resetLearningTestSession();
        break;
      case 2:
        await dbHelper.DatabaseHelper.instance.deleteAllSessions('learning');
        _resetLearningSession();
        break;
      case 3:
        await dbHelper.DatabaseHelper.instance.deleteAllSessions('chatbot');
        unawaited(_resetChatbotSession());
        break;
    }
    _loadHistory();
  }

  Future<void> _onItemTapped(int index) async {
    await _modelResponse.switchContext(_contextKeyForIndex(index));
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  static const _tabLabels = ['Translation', 'Testing', 'Learning', 'Chatbot', 'Setting'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_tabLabels[_selectedIndex]),
      ),
      drawer:
      HistoryDrawer(
        history: _history,
        onSelect: (id) async {
          await _loadSession(id);
        },
        onDelete: (id) async {
          await _deleteSession(id);
        },
        onClear: () async {
          await _deleteAllSession();
        },
        activeSessionId: _activeSessionId[_selectedIndex],
      ),
      onDrawerChanged: (isOpened){
        if (isOpened) {
          _loadHistory();
        }
      },
      body: IndexedStack(
        index: _selectedIndex,
        children: widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.translate),
            label: 'Translation',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.quiz),
            label: 'Testing',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.textsms),
            label: 'Learning',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.keyboard),
            label: 'Chatbot',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Setting',
          ),
        ],
      )
    );
  }
}
