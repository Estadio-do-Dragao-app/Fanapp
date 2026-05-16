import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/home_view_model.dart';

void main() {
  group('HomeViewModel', () {
    late HomeViewModel viewModel;

    setUp(() {
      viewModel = HomeViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('initial state has no selected tab', () {
      expect(viewModel.selectedIndex, 0);
    });

    test('setSelectedIndex updates index and notifies listeners', () {
      int notifyCount = 0;
      viewModel.addListener(() => notifyCount++);

      viewModel.setSelectedIndex(1);

      expect(viewModel.selectedIndex, 1);
      expect(notifyCount, greaterThan(0));
    });

    test('setSelectedIndex to same value still updates', () {
      viewModel.setSelectedIndex(0);
      final before = viewModel.selectedIndex;
      viewModel.setSelectedIndex(0);
      expect(viewModel.selectedIndex, before);
    });

    test('setSelectedIndex handles multiple updates in sequence', () {
      viewModel.setSelectedIndex(0);
      viewModel.setSelectedIndex(1);
      viewModel.setSelectedIndex(2);
      expect(viewModel.selectedIndex, 2);
    });

    test('dispose does not throw', () {
      expect(() => viewModel.dispose(), returnsNormally);
    });
  });
}
