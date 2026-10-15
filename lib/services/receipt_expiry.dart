import 'dart:convert';
import 'dart:typed_data';

/// Lit, dans le recu App Store present sur l'appareil, la date d'expiration
/// d'un abonnement. Aucun reseau, aucun serveur : le recu (PKCS#7, encodage
/// BER) liste chaque achat avec sa date `expires_date` (attribut 1708) et son
/// produit (attribut 1702), au sein d'un attribut « achat integre » (17).
///
/// Sert a refuser une « restauration » qui ne renvoie qu'un abonnement DEJA
/// EXPIRE : StoreKit renvoie bien ces transactions comme `restored`.
///
/// Prudence maximale : en cas de doute (recu illisible, produit absent, date
/// absente) on renvoie null, et l'appelant se comporte comme avant. Un abonne
/// ne doit jamais etre refuse a cause d'un recu mal lu.
class ReceiptExpiry {
  ReceiptExpiry._();

  /// Expiration la plus tardive de [productId] dans [receiptBase64], en UTC,
  /// ou null si elle n'a pas pu etre lue.
  static DateTime? latestExpiry(String receiptBase64, String productId) {
    try {
      final cleaned = receiptBase64.replaceAll(RegExp(r'\s'), '');
      if (cleaned.isEmpty) return null;
      final bytes = base64.decode(cleaned);
      final found = <DateTime>[];
      _walk(bytes, 0, bytes.length, 0, productId, found, false);
      if (found.isEmpty) return null;
      found.sort();
      return found.last;
    } catch (_) {
      return null;
    }
  }

  /// Parcourt les elements ASN.1 (courts, longs ou de longueur indefinie).
  /// Renvoie la position suivante. Les OCTET STRING sont ouverts : le contenu
  /// du recu s'y trouve imbrique.
  static int _walk(Uint8List b, int start, int end, int depth,
      String productId, List<DateTime> out, bool untilEoc) {
    if (depth > 12) return end;
    var i = start;
    while (i < end) {
      if (untilEoc && i + 1 < end && b[i] == 0 && b[i + 1] == 0) return i + 2;
      final tag = b[i];
      var p = i + 1;
      if (p >= end) throw const FormatException('tronque');
      final l0 = b[p++];
      var indefinite = false;
      var len = 0;
      if (l0 == 0x80) {
        indefinite = true;
      } else if (l0 < 0x80) {
        len = l0;
      } else {
        final n = l0 & 0x7f;
        if (n == 0 || n > 4 || p + n > end) {
          throw const FormatException('longueur');
        }
        for (var k = 0; k < n; k++) {
          len = (len << 8) | b[p++];
        }
      }
      final constructed = (tag & 0x20) != 0;
      if (indefinite) {
        if (!constructed) throw const FormatException('indefini');
        i = _walk(b, p, end, depth + 1, productId, out, true);
        continue;
      }
      final cend = p + len;
      if (cend > end) throw const FormatException('depasse');
      if (tag == 0x30) _checkAttribute(b, p, cend, productId, out);
      if (constructed) {
        _walk(b, p, cend, depth + 1, productId, out, false);
      } else if (tag == 0x04) {
        try {
          _walk(b, p, cend, depth + 1, productId, out, false);
        } catch (_) {
          // Octets quelconques, pas de l'ASN.1 : on ignore.
        }
      }
      i = cend;
    }
    return i;
  }

  /// Element ASN.1 a longueur definie : (tag, debut du contenu, fin).
  static ({int tag, int start, int end})? _tlv(Uint8List b, int i, int end) {
    if (i + 2 > end) return null;
    final tag = b[i];
    var p = i + 1;
    final l0 = b[p++];
    var len = 0;
    if (l0 == 0x80) return null;
    if (l0 < 0x80) {
      len = l0;
    } else {
      final n = l0 & 0x7f;
      if (n == 0 || n > 4 || p + n > end) return null;
      for (var k = 0; k < n; k++) {
        len = (len << 8) | b[p++];
      }
    }
    if (p + len > end) return null;
    return (tag: tag, start: p, end: p + len);
  }

  /// Attribut du recu : SEQUENCE { INTEGER type, INTEGER version,
  /// OCTET STRING valeur }.
  static ({int type, int start, int end})? _attribute(
      Uint8List b, int s, int e) {
    final a = _tlv(b, s, e);
    if (a == null || a.tag != 0x02) return null;
    final c = _tlv(b, a.end, e);
    if (c == null || c.tag != 0x02) return null;
    final d = _tlv(b, c.end, e);
    if (d == null || d.tag != 0x04 || d.end != e) return null;
    var type = 0;
    for (var k = a.start; k < a.end; k++) {
      type = (type << 8) | b[k];
    }
    return (type: type, start: d.start, end: d.end);
  }

  static void _checkAttribute(
      Uint8List b, int s, int e, String productId, List<DateTime> out) {
    final attr = _attribute(b, s, e);
    if (attr == null || attr.type != 17) return;
    final set = _tlv(b, attr.start, attr.end);
    if (set == null || set.tag != 0x31) return;
    String? product;
    String? expires;
    var i = set.start;
    while (i < set.end) {
      final seq = _tlv(b, i, set.end);
      if (seq == null || seq.tag != 0x30) break;
      final inner = _attribute(b, seq.start, seq.end);
      if (inner != null) {
        final v = _tlv(b, inner.start, inner.end);
        if (v != null) {
          final text = String.fromCharCodes(b.sublist(v.start, v.end));
          if (inner.type == 1702) product = text;
          if (inner.type == 1708) expires = text;
        }
      }
      i = seq.end;
    }
    if (product != productId || expires == null || expires.isEmpty) return;
    final date = DateTime.tryParse(expires);
    if (date != null) out.add(date.toUtc());
  }
}
