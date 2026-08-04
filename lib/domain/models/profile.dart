class Profile {
  const Profile({required this.id, this.username, this.avatarUrl});

  final String id;
  final String? username;
  final String? avatarUrl;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: json['username'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );
}
