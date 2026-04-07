import 'package:flutter/material.dart';
import 'package:SLMTranslator/base/base_block.dart';

class StubBlock extends BaseBlock {
  final Exception? throwOnFetch;
  final Duration fetchDelay;
  final bool overrideShowTextField;
  final bool overrideHasOutputContent;

  const StubBlock({
    super.key,
    required super.blockId,
    super.text,
    super.onBusyChanged,
    super.onDelete,
    super.onSendToChatbot,
    super.autoSubmit,
    this.throwOnFetch,
    this.fetchDelay = Duration.zero,
    this.overrideShowTextField = true,
    this.overrideHasOutputContent = false,
  });

  @override
  State<StubBlock> createState() => StubBlockState();
}

class StubBlockState extends BaseBlockState<StubBlock> {
  final List<String> fetchedTexts = [];

  int fetchCallCount = 0;

  @override
  bool get showTextField => widget.overrideShowTextField;

  @override
  bool get hasOutputContent => widget.overrideHasOutputContent;

  @override
  Future<void> fetchResponse(String text) async {
    fetchCallCount++;
    if (widget.fetchDelay > Duration.zero) {
      await Future.delayed(widget.fetchDelay);
    }
    if (widget.throwOnFetch != null) throw widget.throwOnFetch!;
    fetchedTexts.add(text);
  }

  @override
  Widget buildInputHeader() =>
      const Text('Stub Header', key: Key('stub_header'));

  @override
  Widget buildInputFooter() => const SizedBox.shrink();

  @override
  Widget buildOutputContent() =>
      const Text('Stub Output', key: Key('stub_output'));
}

