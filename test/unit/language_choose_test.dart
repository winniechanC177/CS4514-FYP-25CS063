import 'package:flutter_test/flutter_test.dart';
import 'package:SLMTranslator/types/language_choose.dart';

void main() {
	group('LanguageChoose parsing and flags', () {
		test('tryParse supports lowercase enum names', () {
			expect(LanguageChoose.tryParse('english'), LanguageChoose.english);
			expect(LanguageChoose.tryParse('japanese'), LanguageChoose.japanese);
		});

		test('tryParse supports display labels', () {
			expect(LanguageChoose.tryParse('French'), LanguageChoose.french);
			expect(
				LanguageChoose.tryParse('Chinese (Traditional)'),
				LanguageChoose.chineseTraditional,
			);
		});

		test('tryParse maps generic chinese alias to simplified', () {
			expect(LanguageChoose.tryParse('Chinese'), LanguageChoose.chineseSimplified);
			expect(LanguageChoose.tryParse('chinese'), LanguageChoose.chineseSimplified);
		});

		test('tryParse returns null for unknown input', () {
			expect(LanguageChoose.tryParse(null), isNull);
			expect(LanguageChoose.tryParse(''), isNull);
			expect(LanguageChoose.tryParse('Klingon'), isNull);
		});

		test('hasTtsSupport is false only for japanese', () {
			expect(LanguageChoose.japanese.hasTtsSupport, isFalse);
			for (final lang in LanguageChoose.values.where((l) => l != LanguageChoose.japanese)) {
				expect(lang.hasTtsSupport, isTrue, reason: '${lang.name} should have TTS support');
			}
		});
	});
}

