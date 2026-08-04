class RideGroup {
  const RideGroup({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.leaderId,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String leaderId;
  final DateTime createdAt;

  factory RideGroup.fromJson(Map<String, dynamic> json) => RideGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        inviteCode: json['invite_code'] as String,
        leaderId: json['leader_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
