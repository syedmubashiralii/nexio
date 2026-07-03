import 'package:flutter_test/flutter_test.dart';
import 'package:nexio_example/main.dart';

void main() {
  testWidgets('shows the runnable Nexio example', (tester) async {
    await tester.pumpWidget(const NexioExampleApp());

    expect(find.text('Nexio'), findsOneWidget);
    expect(find.text('No users loaded'), findsOneWidget);
    expect(find.text('Load users'), findsOneWidget);
  });
}
