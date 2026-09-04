/// Markdown 文档分块：渲染和复制共用同一份解析结果。
library;

import 'dart:math' as math;
import 'package:markdown/markdown.dart' as markdown;

/// 可被页面独立渲染和复制的顶层 Markdown 块。
enum MarkdownBlockType {
  heading,
  paragraph,
  unorderedList,
  orderedList,
  quote,
  code,
  thematicBreak,
}

class MarkdownBlock {
  const MarkdownBlock({required this.type, required this.raw, this.level = 0});

  final MarkdownBlockType type;

  /// 从源文档截取的原始 Markdown，不经过重新序列化。
  final String raw;

  /// 标题层级；非标题块为 0。
  final int level;

  String get copyText => raw;
}

class MarkdownDocument {
  const MarkdownDocument({required this.source, required this.blocks});
  final String source;
  final List<MarkdownBlock> blocks;

  String toReadableText() {
    final text = blocks.map(_blockToReadable).join('\n\n');
    return text
        .replaceFirst(RegExp(r'^\n+'), '')
        .replaceFirst(RegExp(r'\n+$'), '');
  }
}

class _SourceLine {
  const _SourceLine(this.text, this.raw);
  final String text;
  final String raw;
}

/// 将 API 返回的 Markdown 切成标题、段落、列表、引用和代码等顶层块。
MarkdownDocument parseMarkdownDocument(String source) {
  final lines = _splitLines(source);
  final blocks = <MarkdownBlock>[];
  var index = 0;

  while (index < lines.length) {
    if (_isBlank(lines[index].text)) {
      index++;
      continue;
    }

    final current = lines[index].text;
    final heading = _headingMatch(current);
    if (heading != null) {
      blocks.add(
        MarkdownBlock(
          type: MarkdownBlockType.heading,
          raw: _rawFor(lines, index, index),
          level: heading.level,
        ),
      );
      index++;
      continue;
    }

    final fence = _fenceStart(current);
    if (fence != null) {
      final start = index;
      index++;
      while (index < lines.length && !_isFenceEnd(lines[index].text, fence)) {
        index++;
      }
      if (index < lines.length) index++;
      blocks.add(
        MarkdownBlock(
          type: MarkdownBlockType.code,
          raw: _rawFor(lines, start, index - 1),
        ),
      );
      continue;
    }

    final listType = _listType(current);
    if (listType != null) {
      final start = index;
      index++;
      while (index < lines.length) {
        final text = lines[index].text;
        if (_isBlank(text)) break;
        if (_headingMatch(text) != null ||
            _fenceStart(text) != null ||
            _isQuoteStart(text) ||
            _isThematicBreak(text)) {
          break;
        }
        final nextListType = _listType(text);
        final indented = _leadingSpaces(text) >= 2;
        if (nextListType == null && !indented) break;
        index++;
      }
      blocks.add(
        MarkdownBlock(type: listType, raw: _rawFor(lines, start, index - 1)),
      );
      continue;
    }

    if (_isQuoteStart(current)) {
      final start = index;
      index++;
      while (index < lines.length &&
          !_isBlank(lines[index].text) &&
          _isQuoteStart(lines[index].text)) {
        index++;
      }
      blocks.add(
        MarkdownBlock(
          type: MarkdownBlockType.quote,
          raw: _rawFor(lines, start, index - 1),
        ),
      );
      continue;
    }

    if (_isThematicBreak(current)) {
      blocks.add(
        MarkdownBlock(
          type: MarkdownBlockType.thematicBreak,
          raw: _rawFor(lines, index, index),
        ),
      );
      index++;
      continue;
    }

    final start = index;
    index++;
    while (index < lines.length) {
      final text = lines[index].text;
      if (_isBlank(text) || _startsNewBlock(text)) break;
      index++;
    }
    blocks.add(
      MarkdownBlock(
        type: MarkdownBlockType.paragraph,
        raw: _rawFor(lines, start, index - 1),
      ),
    );
  }

  return MarkdownDocument(source: source, blocks: List.unmodifiable(blocks));
}

List<_SourceLine> _splitLines(String source) {
  if (source.isEmpty) return const [];
  final lines = <_SourceLine>[];
  var start = 0;
  while (start < source.length) {
    final newline = source.indexOf('\n', start);
    if (newline < 0) {
      final raw = source.substring(start);
      lines.add(_SourceLine(_withoutCarriageReturn(raw), raw));
      break;
    }
    final raw = source.substring(start, newline + 1);
    lines.add(
      _SourceLine(
        _withoutCarriageReturn(raw.substring(0, raw.length - 1)),
        raw,
      ),
    );
    start = newline + 1;
  }
  return lines;
}

String _withoutCarriageReturn(String value) =>
    value.endsWith('\r') ? value.substring(0, value.length - 1) : value;

String _rawFor(List<_SourceLine> lines, int start, int end) {
  final value = lines.sublist(start, end + 1).map((line) => line.raw).join();
  return value.replaceFirst(RegExp(r'(?:\r?\n)+$'), '');
}

bool _isBlank(String text) => text.trim().isEmpty;

bool _startsNewBlock(String text) =>
    _headingMatch(text) != null ||
    _fenceStart(text) != null ||
    _listType(text) != null ||
    _isQuoteStart(text) ||
    _isThematicBreak(text);

int _leadingSpaces(String text) => text.length - text.trimLeft().length;

MarkdownBlockType? _listType(String text) {
  final trimmed = text.trimLeft();
  if (RegExp(r'^[-+*]\s+').hasMatch(trimmed)) {
    return MarkdownBlockType.unorderedList;
  }
  if (RegExp(r'^\d+[.)]\s+').hasMatch(trimmed)) {
    return MarkdownBlockType.orderedList;
  }
  return null;
}

bool _isQuoteStart(String text) => RegExp(r'^\s{0,3}>').hasMatch(text);

bool _isThematicBreak(String text) =>
    RegExp(r'^\s{0,3}([-*_])(?:\s*\1){2,}\s*$').hasMatch(text);

String? _fenceStart(String text) {
  final match = RegExp(r'^\s*(`{3,}|~{3,})').firstMatch(text);
  return match?.group(1)?.substring(0, 3);
}

bool _isFenceEnd(String text, String fence) =>
    RegExp('^\\s*${RegExp.escape(fence)}').hasMatch(text);

class _Heading {
  const _Heading(this.level);
  final int level;
}

_Heading? _headingMatch(String text) {
  final match = RegExp(r'^\s{0,3}(#{1,6})\s+').firstMatch(text);
  return match == null ? null : _Heading(math.min(match.group(1)!.length, 6));
}

String _blockToReadable(MarkdownBlock block) {
  switch (block.type) {
    case MarkdownBlockType.heading:
      final indent = '  ' * math.max(block.level - 1, 0);
      return block.raw
          .split('\n')
          .map((line) => '$indent${_headingText(line)}')
          .join('\n');
    case MarkdownBlockType.paragraph:
      return _plainInline(block.raw);
    case MarkdownBlockType.quote:
      return _plainInline(block.raw.split('\n').map(_quoteText).join('\n'));
    case MarkdownBlockType.unorderedList:
      return block.raw
          .split('\n')
          .map((line) {
            final item = _listItemText(line);
            return '${item.indent}• ${_plainInline(item.text)}';
          })
          .join('\n');
    case MarkdownBlockType.orderedList:
      return block.raw
          .split('\n')
          .map((line) {
            final item = _orderedItemText(line);
            if (item.number == null) {
              return '${item.indent}${_plainInline(item.text)}';
            }
            return '${item.indent}${item.number}. ${_plainInline(item.text)}';
          })
          .join('\n');
    case MarkdownBlockType.code:
      final lines = block.raw.split('\n');
      final fence = lines.isEmpty ? null : _fenceStart(lines.first);
      if (lines.length >= 2 && fence != null) {
        lines.removeAt(0);
        if (lines.isNotEmpty && _isFenceEnd(lines.last, fence)) {
          lines.removeLast();
        }
      }
      return lines.join('\n');
    case MarkdownBlockType.thematicBreak:
      return '';
  }
}

String _plainInline(String text) {
  final nodes = markdown.Document().parseInline(text);
  return nodes.map((node) => node.textContent).join();
}

String _headingText(String line) {
  final value = line.trimLeft();
  var index = 0;
  while (index < value.length && value.codeUnitAt(index) == 35) {
    index++;
  }
  return index > 0 && index < value.length && value[index] == ' '
      ? value.substring(index + 1).trim()
      : value.trim();
}

String _quoteText(String line) {
  final value = line.trimLeft();
  return value.startsWith('>') ? value.substring(1).trimLeft() : value;
}

class _ListItemText {
  const _ListItemText(this.indent, this.text);
  final String indent;
  final String text;
}

_ListItemText _listItemText(String line) {
  final indentLength = _leadingSpaces(line);
  final indent = line.substring(0, indentLength);
  final value = line.substring(indentLength);
  if (value.length >= 2 &&
      (value[0] == '-' || value[0] == '+' || value[0] == '*') &&
      value[1].trim().isEmpty) {
    return _ListItemText(indent, value.substring(2));
  }
  return _ListItemText(indent, value);
}

class _OrderedItemText {
  const _OrderedItemText(this.indent, this.number, this.text);
  final String indent;
  final String? number;
  final String text;
}

_OrderedItemText _orderedItemText(String line) {
  final indentLength = _leadingSpaces(line);
  final indent = line.substring(0, indentLength);
  final value = line.substring(indentLength);
  var index = 0;
  while (index < value.length && _isDigit(value.codeUnitAt(index))) {
    index++;
  }
  if (index == 0 ||
      index + 1 >= value.length ||
      (value[index] != '.' && value[index] != ')') ||
      value[index + 1].trim().isNotEmpty) {
    return _OrderedItemText(indent, null, value);
  }
  return _OrderedItemText(
    indent,
    value.substring(0, index),
    value.substring(index + 2),
  );
}

bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;
