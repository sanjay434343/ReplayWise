class UserSettings {
  final String key;
  final String value;

  UserSettings({required this.key, required this.value});

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      key: map['key'] as String,
      value: map['value'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
    };
  }
}
