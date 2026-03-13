import 'package:flutter_test/flutter_test.dart';
import 'package:face_cluster/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const FaceClusterApp());
    expect(find.text('FaceCluster'), findsOneWidget);
  });
}
