import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapinou/models/care.dart';
import 'package:lapinou/widgets/app_icon.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(home: Scaffold(body: Center(child: child))),
);

ColorFilter? _filterOf(WidgetTester tester) =>
    tester.widget<SvgPicture>(find.byType(SvgPicture)).colorFilter;

void main() {
  test('every icon is a declared, loadable and non-empty SVG asset', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final icon in AppIcons.values) {
      final svg = await rootBundle.loadString(icon.asset);
      expect(svg, startsWith('<svg'), reason: icon.name);
      expect(svg, contains('viewBox'), reason: icon.name);
      expect(svg, contains(' d="M'), reason: icon.name);
    }
  });

  testWidgets('the icon takes the requested colour and size', (tester) async {
    await _pump(tester, const AppIcon(AppIcons.rabbit, size: 40, color: Colors.red));
    await tester.pumpAndSettle();

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect((svg.width, svg.height), (40, 40));
    expect(_filterOf(tester), const ColorFilter.mode(Colors.red, BlendMode.srcIn));
  });

  testWidgets('the colour follows a change (black on white, white on black)', (
    tester,
  ) async {
    await _pump(tester, const AppIcon(AppIcons.syringe, color: Colors.black));
    await tester.pumpAndSettle();
    expect(_filterOf(tester), const ColorFilter.mode(Colors.black, BlendMode.srcIn));

    await _pump(tester, const AppIcon(AppIcons.syringe, color: Colors.white));
    await tester.pumpAndSettle();
    expect(_filterOf(tester), const ColorFilter.mode(Colors.white, BlendMode.srcIn));
  });

  testWidgets('without a colour it follows the icon theme like a Material icon', (
    tester,
  ) async {
    await _pump(
      tester,
      const IconTheme(
        data: IconThemeData(color: Colors.blue),
        child: AppIcon(AppIcons.nest),
      ),
    );
    await tester.pumpAndSettle();
    expect(_filterOf(tester), const ColorFilter.mode(Colors.blue, BlendMode.srcIn));
  });

  testWidgets('vaccines show the syringe, other care families keep their emoji', (
    tester,
  ) async {
    await _pump(tester, const CareCategoryIcon(CareCategory.vaccine));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);

    await _pump(tester, const CareCategoryIcon(CareCategory.vitamin));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.text(CareCategory.vitamin.emoji), findsOneWidget);
  });
}
