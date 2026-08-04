class GroupMember {
  const GroupMember({
    required this.userId,
    this.username,
    this.avatarUrl,
    required this.role,
    required this.status,
    required this.joinedAt,
  });

  final String userId;
  final String? username;
  final String? avatarUrl;
  final String role;
  final String status;
  final DateTime joinedAt;

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        userId: json['user_id'] as String,
        username: json['username'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        role: json['role'] as String,
        status: json['status'] as String,
        joinedAt: DateTime.parse(json['joined_at'] as String),
      );
}
