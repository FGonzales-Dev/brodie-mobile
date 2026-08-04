class GroupTrip {
  const GroupTrip({
    required this.id,
    this.groupId,
    this.name,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String? groupId;
  final String? name;
  final String status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  factory GroupTrip.fromJson(Map<String, dynamic> json) => GroupTrip(
        id: json['id'] as String,
        groupId: json['group_id'] as String?,
        name: json['name'] as String?,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
        endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String) : null,
      );
}
