import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/features/navigation/data/models/navigation_instruction.dart';

void main() {
  group('NavigationInstruction', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final instruction = NavigationInstruction(
          type: 'left',
          distanceToNextTurn: 50.0,
          nodeId: 'N1',
        );
        expect(instruction.type, 'left');
        expect(instruction.distanceToNextTurn, 50.0);
        expect(instruction.nodeId, 'N1');
        expect(instruction.streetName, isNull);
      });

      test('accepts optional streetName', () {
        final instruction = NavigationInstruction(
          type: 'right',
          distanceToNextTurn: 20.0,
          nodeId: 'N2',
          streetName: 'Gate A',
        );
        expect(instruction.streetName, 'Gate A');
      });
    });

    group('iconPath', () {
      test('left returns turn_left icon', () {
        final i = NavigationInstruction(type: 'left', distanceToNextTurn: 10, nodeId: 'N1');
        expect(i.iconPath, 'assets/icons/turn_left.png');
      });

      test('right returns turn_right icon', () {
        final i = NavigationInstruction(type: 'right', distanceToNextTurn: 10, nodeId: 'N1');
        expect(i.iconPath, 'assets/icons/turn_right.png');
      });

      test('straight returns straight icon', () {
        final i = NavigationInstruction(type: 'straight', distanceToNextTurn: 10, nodeId: 'N1');
        expect(i.iconPath, 'assets/icons/straight.png');
      });

      test('arrive returns arrive icon', () {
        final i = NavigationInstruction(type: 'arrive', distanceToNextTurn: 5, nodeId: 'N1');
        expect(i.iconPath, 'assets/icons/arrive.png');
      });

      test('unknown type returns straight icon as default', () {
        final i = NavigationInstruction(type: 'stairs', distanceToNextTurn: 10, nodeId: 'N1');
        expect(i.iconPath, 'assets/icons/straight.png');
      });
    });

    group('getDescription', () {
      String translate(String key) => key; // identity translate for testing

      test('left calls translate with turn_left', () {
        final i = NavigationInstruction(type: 'left', distanceToNextTurn: 10, nodeId: 'N1');
        expect(i.getDescription(translate), 'turn_left');
      });

      test('right calls translate with turn_right', () {
        final i = NavigationInstruction(type: 'right', distanceToNextTurn: 10, nodeId: 'N1');
        expect(i.getDescription(translate), 'turn_right');
      });

      test('straight calls translate with continue_straight', () {
        final i = NavigationInstruction(type: 'straight', distanceToNextTurn: 10, nodeId: 'N1');
        expect(i.getDescription(translate), 'continue_straight');
      });

      test('arrive calls translate with arrive_at_destination', () {
        final i = NavigationInstruction(type: 'arrive', distanceToNextTurn: 5, nodeId: 'N1');
        expect(i.getDescription(translate), 'arrive_at_destination');
      });

      test('unknown type returns empty string', () {
        final i = NavigationInstruction(type: 'ramp', distanceToNextTurn: 10, nodeId: 'N1');
        expect(i.getDescription(translate), '');
      });

      test('uses provided translate function', () {
        final i = NavigationInstruction(type: 'left', distanceToNextTurn: 10, nodeId: 'N1');
        expect(i.getDescription((_) => 'Virar à esquerda'), 'Virar à esquerda');
      });
    });

    group('formattedDistance', () {
      test('less than 1m returns "<1 m"', () {
        final i = NavigationInstruction(type: 'left', distanceToNextTurn: 0.5, nodeId: 'N1');
        expect(i.formattedDistance, '<1 m');
      });

      test('exactly 0m returns "<1 m"', () {
        final i = NavigationInstruction(type: 'arrive', distanceToNextTurn: 0.0, nodeId: 'N1');
        expect(i.formattedDistance, '<1 m');
      });

      test('1m to 9.9m returns no decimal', () {
        final i = NavigationInstruction(type: 'straight', distanceToNextTurn: 5.7, nodeId: 'N1');
        expect(i.formattedDistance, '6 m');
      });

      test('exactly 1m returns "1 m"', () {
        final i = NavigationInstruction(type: 'straight', distanceToNextTurn: 1.0, nodeId: 'N1');
        expect(i.formattedDistance, '1 m');
      });

      test('exactly 9.9m returns "10 m"', () {
        final i = NavigationInstruction(type: 'straight', distanceToNextTurn: 9.9, nodeId: 'N1');
        expect(i.formattedDistance, '10 m');
      });

      test('10m and above returns rounded meters', () {
        final i = NavigationInstruction(type: 'right', distanceToNextTurn: 123.6, nodeId: 'N1');
        expect(i.formattedDistance, '124 m');
      });

      test('exactly 10m returns "10 m"', () {
        final i = NavigationInstruction(type: 'straight', distanceToNextTurn: 10.0, nodeId: 'N1');
        expect(i.formattedDistance, '10 m');
      });
    });
  });
}
