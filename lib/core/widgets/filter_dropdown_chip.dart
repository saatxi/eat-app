import 'package:flutter/material.dart';

/// Builds the entries of a [FilterDropdownChip]'s menu. [close] dismisses the
/// menu and is meant to be called by whichever entry the user picks.
typedef DropdownMenuBuilder = List<Widget> Function(VoidCallback close);

/// A single filter dimension collapsed into one chip: tapping it opens a menu
/// listing the options. Used to keep a screen's filter row to one line instead
/// of one chip per option wrapping across several.
///
/// [selectedLabel] is what the chip itself shows (the active value, or the
/// dimension's name); [isActive] drives the chip's selected styling. The check
/// mark is suppressed, matching the Android app: the fill colour already marks
/// the selection, and a tick clips a longer translation inside a narrow chip.
///
/// Ported from `ui/common/FilterDropdownChip.kt`, using `MenuAnchor` rather than
/// `PopupMenuButton` so the chip keeps its own tap handling.
class FilterDropdownChip extends StatefulWidget {
  const FilterDropdownChip({
    super.key,
    required this.selectedLabel,
    required this.isActive,
    required this.menuBuilder,
    this.leading,
  });

  final String selectedLabel;
  final bool isActive;
  final DropdownMenuBuilder menuBuilder;
  final Widget? leading;

  @override
  State<FilterDropdownChip> createState() => _FilterDropdownChipState();
}

class _FilterDropdownChipState extends State<FilterDropdownChip> {
  final MenuController _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _controller,
      menuChildren: widget.menuBuilder(_controller.close),
      builder: (BuildContext context, MenuController controller, Widget? child) {
        return FilterChip(
          selected: widget.isActive,
          onSelected: (_) =>
              controller.isOpen ? controller.close() : controller.open(),
          // FilterChip has no trailing slot, so the down-arrow that says
          // "this opens a menu" rides inside the label.
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(widget.selectedLabel),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
          avatar: widget.leading,
          showCheckmark: false,
        );
      },
    );
  }
}
