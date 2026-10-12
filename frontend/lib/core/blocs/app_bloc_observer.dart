import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Global BlocObserver for monitoring BLoC events, transitions, and errors
/// across the entire Pitch Coach application.
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    if (kDebugMode) {
      debugPrint('[Bloc Event] ${bloc.runtimeType} -> $event');
    }
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    if (kDebugMode) {
      debugPrint(
        '[Bloc Change] ${bloc.runtimeType} -> currentState: ${change.currentState.runtimeType}, '
        'nextState: ${change.nextState.runtimeType}',
      );
    }
  }

  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    super.onTransition(bloc, transition);
    if (kDebugMode) {
      debugPrint(
        '[Bloc Transition] ${bloc.runtimeType} -> event: ${transition.event}, '
        'from: ${transition.currentState.runtimeType} to: ${transition.nextState.runtimeType}',
      );
    }
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    debugPrint('[Bloc Error] ${bloc.runtimeType} -> $error\n$stackTrace');
  }
}
