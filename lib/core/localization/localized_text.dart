/// A piece of content that exists in both supported languages.
///
/// Used for hand-written demo copy and other domain text that cannot be
/// looked up by key. The UI picks one side with [resolve]; the other side
/// is never shown, so Bangla and English never appear together.
class LocalizedText {
  const LocalizedText(this.bn, this.en);

  final String bn;
  final String en;

  String resolve({required bool isBangla}) => isBangla ? bn : en;

  @override
  bool operator ==(Object other) =>
      other is LocalizedText && other.bn == bn && other.en == en;

  @override
  int get hashCode => Object.hash(bn, en);

  @override
  String toString() => 'LocalizedText($bn | $en)';
}
