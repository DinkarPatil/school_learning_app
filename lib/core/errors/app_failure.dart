enum AppFailureCode { invalidContent, corruptProgress, audioUnavailable }

class AppFailure implements Exception {
  const AppFailure({
    required this.code,
    required this.message,
    this.cause,
  });

  const AppFailure.invalidContent({Object? cause})
      : this(
          code: AppFailureCode.invalidContent,
          message: 'Learning content is unavailable.',
          cause: cause,
        );

  const AppFailure.corruptProgress({Object? cause})
      : this(
          code: AppFailureCode.corruptProgress,
          message: 'Saved progress could not be read.',
          cause: cause,
        );

  const AppFailure.audioUnavailable({Object? cause})
      : this(
          code: AppFailureCode.audioUnavailable,
          message: 'Audio is unavailable right now.',
          cause: cause,
        );

  final AppFailureCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'AppFailure($code, $message)';
}
