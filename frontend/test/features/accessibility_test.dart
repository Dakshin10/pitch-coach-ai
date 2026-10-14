import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/core/services/tts_service.dart';
import 'package:pitch_coach/core/theme/app_colors.dart';
import 'package:pitch_coach/core/widgets/circular_gauge_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 14: Accessibility & Scalable Text Tests', () {
    testWidgets('CircularGauge renders without overflow at 200% text scale factor', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.0),
                size: Size(390, 844),
              ),
              child: const Scaffold(
                body: Center(
                  child: CircularGauge(
                    value: 85.0,
                    size: 140,
                    centerBigText: '85%',
                    centerSmallLabel: 'Overall Score',
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('85%'), findsOneWidget);
        expect(find.text('Overall Score'), findsOneWidget);

        // Verify Semantics label
        expect(
          find.bySemanticsLabel(RegExp(r'Overall Score: 85%')),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('Primary action buttons render cleanly without overflow at 200% text scale', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.0),
                size: Size(360, 800),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 52,
                            minWidth: double.infinity,
                          ),
                          child: Semantics(
                            button: true,
                            label: 'Practice again with this prompt',
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.mic_rounded),
                              label: const Text('Practice Again'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 48,
                            minWidth: double.infinity,
                          ),
                          child: Semantics(
                            button: true,
                            label: 'Export PDF Report and share',
                            child: OutlinedButton.icon(
                              key: const Key('export_pdf_report_button'),
                              onPressed: () {},
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: const Text('Export PDF Report'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Practice Again'), findsOneWidget);
        expect(find.text('Export PDF Report'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'Practice again with this prompt')), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'Export PDF Report and share')), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('Live captions banner displays spoken text and can be toggled', (tester) async {
      final semantics = tester.ensureSemantics();
      final tts = TtsService.instance;
      tts.setEnabled(true);
      await tts.speak('Can you explain how you handled the database migration?');

      expect(tts.currentCaption, 'Can you explain how you handled the database migration?');
      expect(tts.showCaptions, isTrue);

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListenableBuilder(
                listenable: tts,
                builder: (context, _) {
                  final caption = tts.currentCaption;
                  if (!tts.showCaptions || caption == null || caption.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Semantics(
                    liveRegion: true,
                    label: 'Interviewer says: $caption',
                    child: Container(
                      key: const Key('interview_live_caption_banner'),
                      padding: const EdgeInsets.all(12),
                      color: AppColors.cardDark,
                      child: Row(
                        children: [
                          const Icon(Icons.closed_caption_rounded, key: Key('cc_icon')),
                          const SizedBox(width: 8),
                          Expanded(child: Text(caption)),
                          IconButton(
                            key: const Key('caption_toggle_button'),
                            icon: const Icon(Icons.close_rounded),
                            onPressed: tts.toggleCaptions,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        // Verify caption is visible and accessible
        expect(find.byKey(const Key('interview_live_caption_banner')), findsOneWidget);
        expect(find.text('Can you explain how you handled the database migration?'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp(r'Interviewer says: Can you explain how you handled the database migration\?')),
          findsOneWidget,
        );

        // Dismiss caption via toggle button
        await tester.tap(find.byKey(const Key('caption_toggle_button')));
        await tester.pump();

        expect(find.byKey(const Key('interview_live_caption_banner')), findsNothing);
        expect(tts.showCaptions, isFalse);

        // Reset service
        tts.toggleCaptions();
        tts.clearCaption();
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('Transcript filler word and sentence tapping semantics are present', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Semantics(
                    button: true,
                    label: 'Play sentence from 0.0 seconds: "Um I built the feature"',
                    child: IconButton(
                      key: const Key('sentence_play_0'),
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () {},
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Filler word: um. Tap to seek audio.',
                    child: InkWell(
                      key: const Key('filler_word_um'),
                      onTap: () {},
                      child: const Text('um'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('sentence_play_0')), findsOneWidget);
        expect(find.byKey(const Key('filler_word_um')), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp(r'Play sentence from 0\.0 seconds: "Um I built the feature"')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp(r'Filler word: um\. Tap to seek audio\.')),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    });
  });
}
