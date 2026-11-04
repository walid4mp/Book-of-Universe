import 'package:flutter_test/flutter_test.dart';
import 'package:kawn_library/main.dart';

void main() {
  testWidgets('shows setup guidance when Supabase environment is missing', (tester) async {
    await tester.pumpWidget(const KawnLibraryApp());
    expect(find.text('مكتبة الكون'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });
}
