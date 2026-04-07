import 'package:flutter/material.dart';
import '../base/base_block.dart';

class LearningTestBlock extends BaseBlock {
  final String question;
  final List<String> options;
  final int correctIndex;

  const LearningTestBlock({
    super.key,
    required super.blockId,
    super.onDelete,
    super.onSendToChatbot,
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  @override
  State<LearningTestBlock> createState() => _LearningTestBlockState();
}

class _LearningTestBlockState extends BaseBlockState<LearningTestBlock> {
  int? _selectedAnswer;
  bool _showResult = false;

  @override
  bool get showTextField => false;

  @override
  Future<void> fetchResponse(String text) async {}

  @override
  String buildSendToChatbotText() {
    final optionsText = List.generate(
      widget.options.length,
      (i) => '${String.fromCharCode(65 + i)}. ${widget.options[i]}',
    ).join('\n');
    final answer = widget.options[widget.correctIndex];
    return 'Question: ${widget.question}\n'
        'Options:\n$optionsText\n'
        'Correct answer: $answer';
  }

  void _onAnswerSelected(int index) {
    if (_showResult) return;
    setState(() {
      _selectedAnswer = index;
      _showResult = true;
    });
  }

  void _resetQuiz() {
    setState(() {
      _selectedAnswer = null;
      _showResult = false;
    });
  }

  @override
  Widget buildInputHeader() => Text(
        widget.question,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      );

  @override
  Widget buildInputFooter() => const SizedBox.shrink();

  @override
  Widget buildOutputContent() => Column(
        children: [
          Column(
            children: List.generate(widget.options.length, (index) {
              final option = widget.options[index];
              final isCorrect = index == widget.correctIndex;
              final isSelected = _selectedAnswer == index;

              Color? backgroundColor;
              if (_showResult && isSelected) {
                backgroundColor =
                    isCorrect ? Colors.green.shade100 : Colors.red.shade100;
              } else if (_showResult && isCorrect) {
                backgroundColor = Colors.green.shade100;
              }

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _showResult && isCorrect
                        ? Colors.green
                        : (_showResult && isSelected && !isCorrect)
                            ? Colors.red
                            : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: ListTile(
                  title: Text(
                    option,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: _showResult && isCorrect
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: _showResult
                      ? Icon(
                          isCorrect
                              ? Icons.check_circle
                              : (isSelected
                                  ? Icons.cancel
                                  : Icons.circle_outlined),
                          color: isCorrect
                              ? Colors.green
                              : (isSelected ? Colors.red : Colors.grey),
                        )
                      : null,
                  onTap: _showResult ? null : () => _onAnswerSelected(index),
                ),
              );
            }),
          ),
          if (_showResult) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  _selectedAnswer == widget.correctIndex
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: _selectedAnswer == widget.correctIndex
                      ? Colors.green
                      : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedAnswer == widget.correctIndex
                        ? 'Correct!'
                        : 'Incorrect — correct answer: ${widget.options[widget.correctIndex]}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _selectedAnswer == widget.correctIndex
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _resetQuiz,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ],
        ],
      );
}
