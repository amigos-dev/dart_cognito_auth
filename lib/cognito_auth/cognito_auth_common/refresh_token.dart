import 'package:meta/meta.dart';

const Duration veryLongTime = Duration(days: 365 * 100);

@immutable
class RefreshToken {
  final String rawToken;
  final DateTime createTime;

  const RefreshToken._constant({required this.rawToken, required this.createTime});

  factory RefreshToken({required String rawToken, DateTime? createTime}) {
    createTime = (createTime ?? DateTime.now()).toUtc();
    final result = RefreshToken._constant(rawToken: rawToken, createTime: createTime);
    return result;
  }

  factory RefreshToken.unserialize(String serialized) {
    String? rawToken;
    DateTime? createTime;
    final parts = serialized.split(':');
    if (parts.length >= 4 && parts[0] == '[rt]') {
      final version = int.parse(parts[1]);
      if (version != 1) {
        throw "Unknown serialized refresh token version $version";
      }
      final createTimeMs = int.parse(parts[2]);
      createTime = DateTime.fromMillisecondsSinceEpoch(createTimeMs, isUtc: true);
      rawToken = parts.sublist(3).join(':');
    }
    rawToken = rawToken ?? serialized;
    final result = RefreshToken(rawToken: rawToken, createTime: createTime);
    return result;
  }

  String serialize() {
    final msSinceEpoch = createTime.millisecondsSinceEpoch;
    return "[rt]:1:$msSinceEpoch:$rawToken";
  }

  Duration getRemainingDuration({required Duration expireDuration, Duration graceDuration = Duration.zero}) {
    Duration remaining;
    if (expireDuration == Duration.zero) {
      remaining = veryLongTime;
    } else {
      final authTime = createTime;
      final current = DateTime.now().toUtc();
      final elapsed = current.difference(authTime);
      remaining = expireDuration - elapsed - graceDuration;
    }
    return remaining;
  }

  /// Returns true if the amount of remaining time on the refresh token is
  /// less than an acceptable grace period.
  bool isStale({required Duration expireDuration, Duration graceDuration = Duration.zero}) {
    return getRemainingDuration(expireDuration: expireDuration, graceDuration: graceDuration) <= Duration.zero;
  }

  @override
  String toString() {
    return "RefreshToken(rawToken: '$rawToken', createTime: $createTime)";
  }
}
