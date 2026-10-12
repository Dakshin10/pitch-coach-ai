import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Verify zero emojis exist in frontend lib/ code', () {
    // Audit regex matching all unicode emoji ranges
    final emojiRegex = RegExp(
      r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}\u{1F1E6}-\u{1F1FF}]',
      unicode: true,
    );

    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final matches = emojiRegex.allMatches(line);
          if (matches.isNotEmpty) {
            final matchedChars = matches.map((m) => m.group(0)).join(', ');
            violations.add(
              '${entity.path}:${i + 1} -> [$matchedChars] in "$line"',
            );
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Found emojis in lib/ source files:\n${violations.join('\n')}',
    );
  });
}
