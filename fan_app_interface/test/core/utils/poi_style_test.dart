import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fan_app_interface/core/utils/poi_style.dart';

void main() {
  group('POIStyle', () {
    group('getCategoryIcon', () {
      test('restroom returns wc icon', () {
        expect(POIStyle.getCategoryIcon('restroom'), Icons.wc);
      });

      test('wc returns wc icon', () {
        expect(POIStyle.getCategoryIcon('wc'), Icons.wc);
      });

      test('case insensitive: WC returns wc icon', () {
        expect(POIStyle.getCategoryIcon('WC'), Icons.wc);
      });

      test('cgd returns account_balance icon', () {
        expect(POIStyle.getCategoryIcon('cgd'), Icons.account_balance);
      });

      test('atm returns account_balance icon', () {
        expect(POIStyle.getCategoryIcon('atm'), Icons.account_balance);
      });

      test('food returns restaurant icon', () {
        expect(POIStyle.getCategoryIcon('food'), Icons.restaurant);
      });

      test('restaurant returns restaurant icon', () {
        expect(POIStyle.getCategoryIcon('restaurant'), Icons.restaurant);
      });

      test('cafe returns local_cafe icon', () {
        expect(POIStyle.getCategoryIcon('cafe'), Icons.local_cafe);
      });

      test('bar returns local_bar icon', () {
        expect(POIStyle.getCategoryIcon('bar'), Icons.local_bar);
      });

      test('emergency_exit returns exit_to_app icon', () {
        expect(POIStyle.getCategoryIcon('emergency_exit'), Icons.exit_to_app);
      });

      test('first_aid returns local_hospital icon', () {
        expect(POIStyle.getCategoryIcon('first_aid'), Icons.local_hospital);
      });

      test('information returns info_outline icon', () {
        expect(POIStyle.getCategoryIcon('information'), Icons.info_outline);
      });

      test('stairs returns stairs icon', () {
        expect(POIStyle.getCategoryIcon('stairs'), Icons.stairs);
      });

      test('ramp returns accessible_forward icon', () {
        expect(POIStyle.getCategoryIcon('ramp'), Icons.accessible_forward);
      });

      test('entrance returns login icon', () {
        expect(POIStyle.getCategoryIcon('entrance'), Icons.login);
      });

      test('library returns local_library icon', () {
        expect(POIStyle.getCategoryIcon('library'), Icons.local_library);
      });

      test('parking returns local_parking icon', () {
        expect(POIStyle.getCategoryIcon('parking'), Icons.local_parking);
      });

      test('unknown category returns place icon', () {
        expect(POIStyle.getCategoryIcon('unknown_category'), Icons.place);
      });

      test('empty string returns place icon', () {
        expect(POIStyle.getCategoryIcon(''), Icons.place);
      });
    });

    group('getIcon (wrapper)', () {
      test('delegates to getCategoryIcon', () {
        expect(POIStyle.getIcon('wc'), equals(POIStyle.getCategoryIcon('wc')));
        expect(POIStyle.getIcon('food'), equals(POIStyle.getCategoryIcon('food')));
        expect(POIStyle.getIcon('parking'), equals(POIStyle.getCategoryIcon('parking')));
      });

      test('accepts optional name parameter', () {
        expect(POIStyle.getIcon('restroom', name: 'WC 1'), Icons.wc);
      });
    });

    group('getColor', () {
      test('restroom returns sky blue', () {
        expect(POIStyle.getColor('restroom'), const Color(0xFF42A5F5));
      });

      test('wc returns sky blue', () {
        expect(POIStyle.getColor('wc'), const Color(0xFF42A5F5));
      });

      test('cgd returns CGD blue', () {
        expect(POIStyle.getColor('cgd'), const Color(0xFF1E88E5));
      });

      test('atm returns CGD blue', () {
        expect(POIStyle.getColor('atm'), const Color(0xFF1E88E5));
      });

      test('food returns coral orange', () {
        expect(POIStyle.getColor('food'), const Color(0xFFFF8A65));
      });

      test('restaurant returns coral orange', () {
        expect(POIStyle.getColor('restaurant'), const Color(0xFFFF8A65));
      });

      test('cafe returns coffee brown', () {
        expect(POIStyle.getColor('cafe'), const Color(0xFFA1887F));
      });

      test('bar returns bright purple', () {
        expect(POIStyle.getColor('bar'), const Color(0xFFAB47BC));
      });

      test('emergency_exit returns red', () {
        expect(POIStyle.getColor('emergency_exit'), const Color(0xFFEF5350));
      });

      test('first_aid returns teal green', () {
        expect(POIStyle.getColor('first_aid'), const Color(0xFF26A69A));
      });

      test('information returns cyan-blue', () {
        expect(POIStyle.getColor('information'), const Color(0xFF29B6F6));
      });

      test('entrance returns fresh green', () {
        expect(POIStyle.getColor('entrance'), const Color(0xFF66BB6A));
      });

      test('stairs returns bright amber', () {
        expect(POIStyle.getColor('stairs'), const Color(0xFFFFCA28));
      });

      test('ramp returns bright amber', () {
        expect(POIStyle.getColor('ramp'), const Color(0xFFFFCA28));
      });

      test('library returns rich brown', () {
        expect(POIStyle.getColor('library'), const Color(0xFF8D6E63));
      });

      test('parking returns slate blue-grey', () {
        expect(POIStyle.getColor('parking'), const Color(0xFF78909C));
      });

      test('unknown category returns medium grey', () {
        expect(POIStyle.getColor('unknown'), const Color(0xFF757575));
      });

      test('case insensitive: FOOD returns coral orange', () {
        expect(POIStyle.getColor('FOOD'), const Color(0xFFFF8A65));
      });

      test('accepts optional name parameter', () {
        expect(POIStyle.getColor('bar', name: 'Bar A'), const Color(0xFFAB47BC));
      });
    });
  });
}
