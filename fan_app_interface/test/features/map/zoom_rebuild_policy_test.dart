import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/features/map/presentation/fan_map_page.dart';

void main() {
  group('shouldRebuildOnZoom (Fix 3 regression lock)', () {
    test('tiny zoom delta (within step) does NOT trigger a rebuild', () {
      // A 0.05 step caused per-frame setStates during animated zoom and made
      // the whole map shake. With step=0.25 this must be a no-op.
      expect(shouldRebuildOnZoom(18.0, 18.05), isFalse);
      expect(shouldRebuildOnZoom(18.0, 18.20), isFalse);
      expect(shouldRebuildOnZoom(18.0, 17.80), isFalse);
    });

    test('zoom delta larger than step triggers a rebuild', () {
      expect(shouldRebuildOnZoom(18.0, 18.30), isTrue);
      expect(shouldRebuildOnZoom(18.0, 17.70), isTrue);
    });

    test('crossing the POI visibility cutoff (17.5) always triggers a rebuild,'
        ' even for sub-step deltas', () {
      // Even a 0.01 change must rebuild if it changes POI visibility.
      expect(shouldRebuildOnZoom(17.51, 17.49), isTrue);
      expect(shouldRebuildOnZoom(17.49, 17.51), isTrue);
    });

    test('staying on the same side of the POI cutoff does not rebuild for '
        'sub-step deltas', () {
      expect(shouldRebuildOnZoom(17.40, 17.45), isFalse); // both below
      expect(shouldRebuildOnZoom(17.55, 17.60), isFalse); // both above
    });

    test('zero delta is a no-op', () {
      expect(shouldRebuildOnZoom(18.0, 18.0), isFalse);
    });

    test('custom step and cutoff are respected', () {
      expect(shouldRebuildOnZoom(15.0, 15.10, step: 0.5), isFalse);
      expect(shouldRebuildOnZoom(15.0, 15.60, step: 0.5), isTrue);
      // Cross a custom cutoff
      expect(shouldRebuildOnZoom(16.0, 16.10, poiCutoff: 16.05, step: 0.5),
          isTrue);
    });
  });
}
