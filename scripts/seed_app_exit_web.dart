import 'package:seafoundry_app/services/logging_service.dart';

Future<void> exitApp() async {
  // On web, don't call SystemNavigator.pop() as it may terminate before
  // async operations complete. The Node.js wrapper will kill the process
  // after seeing SEEDING_COMPLETE.
  LoggingService.instance.info(
    'Web exit - keeping process alive for wrapper to terminate.',
  );
  // Add a small delay to ensure any final log statements are flushed
  await Future.delayed(const Duration(seconds: 2));
}
