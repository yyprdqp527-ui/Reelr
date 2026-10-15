import 'package:flutter_test/flutter_test.dart';
import 'package:reelr/services/receipt_expiry.dart';

// Recus synthetiques (BER a longueurs indefinies, comme un vrai recu App Store).
const _pid = 'com.reelr.app.premium.yearly';
const _expired = 'MIAGCSqGSIb3DQEHAaCAMIACAQExADCCARkGCSqGSIb3DQEHAaCABIIBBjGCAQIwDQIBEwIBAQQFDAMxLjAwVAIBEQIBAQRMMUowJwICBqYCAQEEHgwcY29tLnJlZWxyLmFwcC5wcmVtaXVtLnllYXJseTAfAgIGrAIBAQQWFhQyMDI1LTAxLTAxVDAwOjAwOjAwWjBUAgERAgEBBEwxSjAnAgIGpgIBAQQeDBxjb20ucmVlbHIuYXBwLnByZW1pdW0ueWVhcmx5MB8CAgasAgEBBBYWFDIwMjUtMDYtMDFUMDA6MDA6MDBaMEUCARECAQEEPTE7MBgCAgamAgEBBA8MDWF1dHJlLnByb2R1aXQwHwICBqwCAQEEFhYUMjA5OS0wMS0wMVQwMDowMDowMFoAAAAAAAAAAA==';
const _active = 'MIAGCSqGSIb3DQEHAaCAMIACAQExADCB0AYJKoZIhvcNAQcBoIAEgb4xgbswDQIBEwIBAQQFDAMxLjAwVAIBEQIBAQRMMUowJwICBqYCAQEEHgwcY29tLnJlZWxyLmFwcC5wcmVtaXVtLnllYXJseTAfAgIGrAIBAQQWFhQyMDI1LTAxLTAxVDAwOjAwOjAwWjBUAgERAgEBBEwxSjAnAgIGpgIBAQQeDBxjb20ucmVlbHIuYXBwLnByZW1pdW0ueWVhcmx5MB8CAgasAgEBBBYWFDIwOTktMDEtMDFUMDA6MDA6MDBaAAAAAAAAAAA=';
const _otherProduct = 'MIAGCSqGSIb3DQEHAaCAMIACAQExADBpBgkqhkiG9w0BBwGggARYMVYwDQIBEwIBAQQFDAMxLjAwRQIBEQIBAQQ9MTswGAICBqYCAQEEDwwNYXV0cmUucHJvZHVpdDAfAgIGrAIBAQQWFhQyMDk5LTAxLTAxVDAwOjAwOjAwWgAAAAAAAAAA';

void main() {
  test('abonnement expire : date la plus tardive du produit', () {
    expect(ReceiptExpiry.latestExpiry(_expired, _pid), DateTime.utc(2025, 6, 1));
  });

  test('abonnement actif : prend l\'expiration la plus tardive', () {
    expect(ReceiptExpiry.latestExpiry(_active, _pid), DateTime.utc(2099, 1, 1));
  });

  test('autre produit seulement : null (jamais de refus par erreur)', () {
    expect(ReceiptExpiry.latestExpiry(_otherProduct, _pid), isNull);
  });

  test('recu illisible ou vide : null', () {
    expect(ReceiptExpiry.latestExpiry('', _pid), isNull);
    expect(ReceiptExpiry.latestExpiry('pas du base64 !', _pid), isNull);
    expect(ReceiptExpiry.latestExpiry('AAAA', _pid), isNull);
  });
}
