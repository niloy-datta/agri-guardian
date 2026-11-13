import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agri_guardian/core/storage/app_database.dart';
import 'package:agri_guardian/features/fields/application/fields_providers.dart';
import 'package:agri_guardian/screens/my_fields.dart';
import 'package:agri_guardian/shared/models/field.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildSubject({
    required List<Field> fields,
    required List<PendingMutation> pendingMutations,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        fieldsControllerProvider.overrideWith(() => _MockFieldsController(fields)),
        pendingMutationsProvider.overrideWith((ref) => Stream.value(pendingMutations)),
      ],
      child: const MaterialApp(
        home: MyFieldsScreen(),
      ),
    );
  }

  testWidgets('renders sync banner and pending field cards when mutations exist', (tester) async {
    final pending = [
      PendingMutation(
        mutationId: 'mut-1',
        type: 'field_create',
        payloadJson: '{"name":"অফলাইন জমি ১"}',
        idempotencyKey: 'key-1',
        status: 'pending',
        attemptCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(buildSubject(fields: [], pendingMutations: pending));
    await tester.pumpAndSettle();

    expect(find.text('অফলাইন সিঙ্ক কিউ'), findsOneWidget);
    expect(find.text('এখন সিঙ্ক করুন'), findsOneWidget);
    expect(find.text('অফলাইন জমি ১'), findsOneWidget);
    expect(find.text('সিঙ্কের অপেক্ষায়'), findsWidgets);
  });
}

class _MockFieldsController extends FieldsController {
  final List<Field> _initialFields;

  _MockFieldsController(this._initialFields);

  @override
  Future<List<Field>> build() async {
    return _initialFields;
  }
}
