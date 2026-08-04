class Profile {
  const Profile({required this.id, this.displayName, this.avatarUrl});

  final String id;
  final String? displayName;
  final String? avatarUrl;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );
}
