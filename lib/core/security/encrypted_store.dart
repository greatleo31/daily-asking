import 'dart:convert';

class EncryptedStore {
  const EncryptedStore();

  String encodeForPrototype(String plainText) {
    return base64UrlEncode(utf8.encode(plainText));
  }

  String decodeForPrototype(String encoded) {
    return utf8.decode(base64Url.decode(encoded));
  }
}
