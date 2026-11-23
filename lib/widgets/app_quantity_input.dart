import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable quantity stepper and manual numeric input widget.
/// Solves touch target friction, manual typing, and right overflows across all screens.
class AppQuantityInput extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final List<int>? quickIncrements;
  final String? unitSuffix;
  final bool enabled;

  const AppQuantityInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 100000,
    this.step = 1,
    this.quickIncrements,
    this.unitSuffix,
    this.enabled = true,
  });

  @override
  State<AppQuantityInput> createState() => _AppQuantityInputState();
}

class _AppQuantityInputState extends State<AppQuantityInput> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // Auto-select text on focus so user can immediately type a replacement number
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      } else {
        _commitText();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AppQuantityInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final currentTextVal = int.tryParse(_controller.text.trim());
      if (currentTextVal != widget.value) {
        _controller.text = widget.value.toString();
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _commitText() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null || parsed < widget.min) {
      _controller.text = widget.min.toString();
      widget.onChanged(widget.min);
    } else if (parsed > widget.max) {
      _controller.text = widget.max.toString();
      widget.onChanged(widget.max);
    } else if (parsed != widget.value) {
      widget.onChanged(parsed);
    }
  }

  void _increment([int amount = 1]) {
    if (!widget.enabled) return;
    final next = (widget.value + amount).clamp(widget.min, widget.max);
    _controller.text = next.toString();
    widget.onChanged(next);
  }

  void _decrement([int amount = 1]) {
    if (!widget.enabled) return;
    final next = (widget.value - amount).clamp(widget.min, widget.max);
    _controller.text = next.toString();
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final canDecrement = widget.enabled && widget.value > widget.min;
    final canIncrement = widget.enabled && widget.value < widget.max;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Stepper Box
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Minus button
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  icon: const Icon(Icons.remove_rounded, size: 16),
                  color: canDecrement ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                  padding: EdgeInsets.zero,
                  splashRadius: 18,
                  onPressed: canDecrement ? () => _decrement(widget.step) : null,
                ),
              ),

              // Editable text input
              Container(
                width: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  border: Border.symmetric(
                    vertical: BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: false,
                  ),
                  onChanged: (text) {
                    final parsed = int.tryParse(text.trim());
                    if (parsed != null && parsed >= widget.min && parsed <= widget.max) {
                      widget.onChanged(parsed);
                    }
                  },
                  onSubmitted: (_) => _commitText(),
                ),
              ),

              // Plus button
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  icon: const Icon(Icons.add_rounded, size: 16),
                  color: canIncrement ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                  padding: EdgeInsets.zero,
                  splashRadius: 18,
                  onPressed: canIncrement ? () => _increment(widget.step) : null,
                ),
              ),
            ],
          ),
        ),

        // Optional Quick Increments (e.g. +25)
        if (widget.quickIncrements != null && widget.quickIncrements!.isNotEmpty) ...[
          const SizedBox(width: 8),
          ...widget.quickIncrements!.map((inc) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Material(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: widget.enabled ? () => _increment(inc) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      '+$inc',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],

        if (widget.unitSuffix != null && widget.unitSuffix!.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            widget.unitSuffix!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ],
    );
  }
}
