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

    test('initial state has default values', () {
      expect(viewModel.showHeatmap, false);
      expect(viewModel.isHeatmapAvailable, true);
      expect(viewModel.currentFloor, 0);
      expect(viewModel.avoidStairs, false);
      expect(viewModel.isFilterExpanded, false);
      expect(viewModel.isPOIPanelOpen, false);
    });

    test('setHeatmap updates value and notifies', () {
      int notifyCount = 0;
      viewModel.addListener(() => notifyCount++);

      viewModel.setHeatmap(true);

      expect(viewModel.showHeatmap, true);
      expect(notifyCount, greaterThan(0));
    });

    test('setFloor updates current floor', () {
      viewModel.setFloor(2);
      expect(viewModel.currentFloor, 2);
    });

    test('setAvoidStairs updates value', () {
      viewModel.setAvoidStairs(true);
      expect(viewModel.avoidStairs, true);
    });

    test('setFilterExpanded updates value', () {
      viewModel.setFilterExpanded(true);
      expect(viewModel.isFilterExpanded, true);
    });

    test('setPOIPanelOpen updates value', () {
      viewModel.setPOIPanelOpen(true);
      expect(viewModel.isPOIPanelOpen, true);
    });

    test('dispose does not throw', () {
      expect(() => viewModel.dispose(), returnsNormally);
    });
  });
}