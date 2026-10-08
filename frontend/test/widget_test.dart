import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pitch_coach/core/providers/session_results_provider.dart';
import 'package:pitch_coach/core/providers/slide_coach_provider.dart';
import 'package:pitch_coach/core/providers/stats_provider.dart';
import 'package:pitch_coach/core/providers/user_provider.dart';
import 'package:pitch_coach/main.dart';

void main() {
  testWidgets('PitchCoachApp smoke test - initializes MaterialApp',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => StatsProvider()),
          ChangeNotifierProvider(create: (_) => SessionResultsProvider()),
          ChangeNotifierProvider(create: (_) => SlideCoachProvider()),
        ],
        child: const PitchCoachApp(),
      ),
    );

    // Initial frame builds the router and Material components
    await tester.pump();

    // Verify PitchCoachApp is mounted
    expect(find.byType(PitchCoachApp), findsOneWidget);
  });
}
