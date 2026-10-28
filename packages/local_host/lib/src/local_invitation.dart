/// Invitation locale versionnée. Elle ne contient ni identité ni jeton privé.
class LocalInvitation {
  factory LocalInvitation({required String address, required String code}) {
    final match = RegExp(
      r'^([0-9]{1,3}(?:\.[0-9]{1,3}){3}):([0-9]{1,5})$',
    ).firstMatch(address);
    if (match == null)
      throw const FormatException('Adresse du salon invalide.');
    final octets = match.group(1)!.split('.').map(int.parse).toList();
    final port = int.parse(match.group(2)!);
    if (octets.any((part) => part > 255) ||
        octets.first == 0 ||
        octets.first >= 224 ||
        port == 0 ||
        port > 65535) {
      throw const FormatException('Adresse du salon invalide.');
    }
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code))
      throw const FormatException('Code du salon invalide.');
    return LocalInvitation._('${octets.join('.')}:$port', code);
  }
  const LocalInvitation._(this.address, this.code);
  final String address, code;
  String get payload => Uri(
    scheme: 'mordeviel',
    host: 'join',
    queryParameters: {'v': '1', 'address': address, 'code': code},
  ).toString();

  factory LocalInvitation.parse(String raw) {
    final uri = raw.length > 512 ? null : Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme != 'mordeviel' ||
        uri.host != 'join' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.path.isNotEmpty ||
        uri.hasFragment) {
      throw const FormatException(
        'Ce QR code n’est pas une invitation Mordeviel.',
      );
    }
    final all = uri.queryParametersAll;
    if (all.length != 3 ||
        !all.keys.every({'v', 'address', 'code'}.contains) ||
        all.values.any((values) => values.length != 1) ||
        all['v']?.single != '1') {
      throw const FormatException(
        'Invitation Mordeviel invalide ou non prise en charge.',
      );
    }
    return LocalInvitation(
      address: all['address']!.single,
      code: all['code']!.single,
    );
  }
}
