import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// Markdown + LaTeX（$...$ / $$...$$）
class MarkdownView extends StatelessWidget {
  final String data;

  const MarkdownView(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: true,
      builders: {
        'math': MathElementBuilder(),
      },
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        <md.InlineSyntax>[
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          MathInlineSyntax(),
        ],
      ),
      blockSyntaxes: [
        ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        MathBlockSyntax(),
      ],
    );
  }
}

class MathElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final tex = element.textContent;
    final display = element.attributes['display'] == 'true';

    // 添加空值检查
    if (tex == null || tex.isEmpty) {
      return const SizedBox.shrink(); // 如果 tex 为空，则返回一个空的 widget
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Math.tex(
        tex,
        textStyle: preferredStyle,
        mathStyle: display ? MathStyle.display : MathStyle.text,
      ),
    );
  }
}

/// 行内：$...$
class MathInlineSyntax extends md.InlineSyntax {
  MathInlineSyntax() : super(r'\$(.+?)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = match.group(1);
    if (tex == null || tex.trim().isEmpty) return false;

    parser.addNode(
      md.Element.text('math', tex)..attributes['display'] = 'false',
    );
    return true;
  }
}

/// 块级：$$...$$
class MathBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\$\$');

  @override
  bool canParse(md.BlockParser parser) {
    return pattern.hasMatch(parser.current.content);
  }

  @override
  md.Node? parse(md.BlockParser parser) {
    final firstLine = parser.current.content;
    parser.advance();

    final buffer = StringBuffer();

    // 去掉首行 $$
    final first = firstLine.replaceFirst(r'$$', '').trim();
    if (first.isNotEmpty) buffer.writeln(first);

    while (!parser.isDone) {
      final line = parser.current.content;

      if (line.trim().endsWith(r'$$')) {
        final content = line.trim().replaceAll(r'$$', '');
        if (content.isNotEmpty) buffer.writeln(content);
        parser.advance();
        break;
      } else {
        buffer.writeln(line);
        parser.advance();
      }
    }

    final content = buffer.toString().trim();
    if (content.isEmpty) { // 如果内容为空，则不创建 math 节点
      return null;
    }

    return md.Element.text(
      'math',
      content,
    )..attributes['display'] = 'true';
  }
}
