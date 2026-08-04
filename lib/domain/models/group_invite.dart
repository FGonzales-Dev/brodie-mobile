class GroupInvite {
  const GroupInvite({
    required this.groupId,
    required this.groupName,
    this.invitedBy,
    required this.invitedAt,
  });

  final String groupId;
  final String groupName;
  final String? invitedBy;
  final DateTime invitedAt;

  factory GroupInvite.fromJson(Map<String, dynamic> json) => GroupInvite(
        groupId: json['group_id'] as String,
        groupName: json['group_name'] as String,
        invitedBy: json['invited_by'] as String?,
        invitedAt: DateTime.parse(json['invited_at'] as String),
      );
}
