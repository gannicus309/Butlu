/// A shared family note -- insurance details, passport numbers, pediatrician
/// contact, warranty info, anything worth keeping in one place.
class VaultNote {
  final String id;
  final String title;
  final String body;
  final String createdByUid;
  final DateTime updatedAt;

  const VaultNote({
    required this.id,
    required this.title,
    required this.body,
    required this.createdByUid,
    required this.updatedAt,
  });
}
