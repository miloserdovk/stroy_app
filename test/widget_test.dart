import 'package:flutter_test/flutter_test.dart';
import 'package:stroy_app/main.dart';

void main() {
  testWidgets('renders inventory dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('StroyApp Inventory'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Log'), findsOneWidget);
    expect(find.text('Add item'), findsOneWidget);
    expect(find.text('Hammer Drill Makita HR2470'), findsOneWidget);
  });
}
