// Main integration test runner.
//
// Run the full suite on a real device:
//   flutter test integration_test/app_test.dart -d <device-id> --timeout=600s
//
// Or run a single group file directly:
//   flutter test integration_test/sequential_test.dart -d <device-id>

import 'package:integration_test/integration_test.dart';

import 'sequential_test.dart' as sequential;
import 'independent/wird_test.dart' as wird;
import 'independent/search_test.dart' as search;
import 'independent/nav_test.dart' as nav;
import 'independent/autoscroll_test.dart' as autoscroll;
import 'independent/dashboard_test.dart' as dashboard;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── Sequential group (20 tests) ───────────────────────────────────────────
  // State accumulates between tests. Runs in declaration order.
  // Resets device state once via setUpAll at group start.
  sequential.main();

  // ── Independent groups (43 tests) ────────────────────────────────────────
  // Each test resets device state via setUp before running.
  wird.main();
  search.main();
  nav.main();
  autoscroll.main();
  dashboard.main();
}
