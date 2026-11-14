import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../fields/application/fields_providers.dart';
import '../data/rotation_repository.dart';
import '../domain/rotation_models.dart';

final rotationRepositoryProvider = Provider<RotationRepository>((ref) {
  return RotationRepository(ref.watch(apiClientProvider));
});

/// The farmer's saved rotation profile for a field (null = none saved yet).
final rotationProfileProvider =
    FutureProvider.autoDispose.family<RotationProfile?, String>((ref, fieldId) {
  return ref.watch(rotationRepositoryProvider).fetchProfile(fieldId);
});

/// Scenario comparison request: which field and how strict the calendar is.
typedef RotationQuery = ({
  String fieldId,
  int maxOverlapDays,
  String irrigationAccess,
  String priority,
});

final rotationComparisonProvider = FutureProvider.autoDispose
    .family<RotationComparison, RotationQuery>((ref, q) {
  return ref
      .watch(rotationRepositoryProvider)
      .compareForField(
        q.fieldId,
        maxOverlapDays: q.maxOverlapDays,
        irrigationAccess: q.irrigationAccess,
        preferredOutcomes: [q.priority],
      );
});
