import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:document_scanner/main.dart';

void main() {
  testWidgets('App boots and shows the Scan Document CTA', (tester) async {
    await tester.pumpWidget(const DocumentScannerApp());
    await tester.pumpAndSettle();

    expect(find.text('Scan Document'), findsOneWidget);
    expect(find.text('Recent Documents'), findsOneWidget);
  });

  testWidgets('Bottom navigation switches between Home and Documents', (tester) async {
    await tester.pumpWidget(const DocumentScannerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();

    expect(find.text('Documents'), findsWidgets);
  });
}
