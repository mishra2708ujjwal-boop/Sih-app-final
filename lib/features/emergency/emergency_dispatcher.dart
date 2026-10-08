import 'package:flutter/services.dart';

import '../../core/utils/format.dart';
import '../../shared/models/health_reading.dart';
import '../../shared/models/risk_result.dart';
import '../../shared/models/user_profile.dart';

/// A resolved GPS position from the native side.
class GpsFix {
  final double lat;
  final double lng;

  /// Horizontal accuracy in metres, or `null` when the fix carried none.
  final double? accuracyMeters;

  const GpsFix({required this.lat, required this.lng, this.accuracyMeters});

  /// A link any responder can tap to open the exact spot in Google Maps.
  String get mapsLink =>
      'https://maps.google.com/?q=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

  /// Human-readable one-liner for the alert body and the UI.
  String get shortText {
    final acc = accuracyMeters;
    final base = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    return (acc == null || acc <= 0)
        ? base
        : '$base (±${acc.toStringAsFixed(0)} m)';
  }
}

/// Whether each dispatch capability is currently granted on this device.
class EmergencyPermissions {
  final bool sms;
  final bool call;
  final bool location;

  const EmergencyPermissions({
    required this.sms,
    required this.call,
    required this.location,
  });

  const EmergencyPermissions.none()
      : sms = false,
        call = false,
        location = false;

  bool get allGranted => sms && call && location;
}

/// Thin Dart wrapper over the native `prana/emergency` MethodChannel
/// (see android/.../MainActivity.kt).
///
/// Every call is wrapped so that on a platform without the channel (iOS,
/// desktop, widget tests) or when the OS refuses, the app degrades quietly to
/// its manual copy-the-message fallback instead of throwing.
class EmergencyDispatcher {
  static const MethodChannel _channel = MethodChannel('prana/emergency');

  const EmergencyDispatcher();

  /// Pops the OS permission dialogs for SMS, phone and location. Fire-and-forget
  /// — grants are re-checked at dispatch time, not awaited here.
  Future<void> requestPermissions() async {
    try {
      await _channel.invokeMethod<bool>('requestPermissions');
    } catch (_) {
      // No channel / not Android — nothing to request.
    }
  }

  /// Current grant state, used by the Emergency screen to warn if auto-dispatch
  /// will be silently blocked (e.g. on MIUI).
  Future<EmergencyPermissions> permissions() async {
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('permissions');
      if (result == null) return const EmergencyPermissions.none();
      return EmergencyPermissions(
        sms: result['sms'] == true,
        call: result['call'] == true,
        location: result['location'] == true,
      );
    } catch (_) {
      return const EmergencyPermissions.none();
    }
  }

  /// Best available position, or `null` if location is off/denied/unavailable.
  Future<GpsFix?> location() async {
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('getLocation');
      if (result == null) return null;
      final lat = (result['lat'] as num?)?.toDouble();
      final lng = (result['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      final acc = (result['accuracy'] as num?)?.toDouble();
      return GpsFix(
        lat: lat,
        lng: lng,
        accuracyMeters: (acc == null || acc < 0) ? null : acc,
      );
    } catch (_) {
      return null;
    }
  }

  /// Sends [message] to [phone] via SmsManager. Returns whether it was sent.
  Future<bool> sendSms(String phone, String message) async {
    try {
      final ok = await _channel.invokeMethod<bool>('sendSms', {
        'phone': _normalizePhone(phone),
        'message': message,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Places a call to [phone]. Returns `'called'` (auto-dialled), `'dialer'`
  /// (opened prefilled), or `'failed'`.
  Future<String> placeCall(String phone) async {
    try {
      final status = await _channel.invokeMethod<String>('placeCall', {
        'phone': _normalizePhone(phone),
      });
      return status ?? 'failed';
    } catch (_) {
      return 'failed';
    }
  }

  /// Keep a leading `+` (country code) but drop spaces, dashes and brackets so
  /// `tel:` and SmsManager get a clean dialable string.
  static String _normalizePhone(String raw) {
    final trimmed = raw.trim();
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return trimmed.startsWith('+') ? '+$digits' : digits;
  }
}

/// Builds the alert text shared by the SMS body (controller) and the on-screen
/// message (Emergency screen). Single source of truth so the two never drift.
///
/// [gpsText]/[mapsLink] come from a resolved [GpsFix]; while a fix is still
/// being acquired the caller passes `gpsText: 'Locating…'` and no link.
String buildEmergencyMessage({
  required UserProfile profile,
  required HealthReading health,
  required RiskResult risk,
  required bool hasLiveData,
  required DateTime raisedAt,
  String? gpsText,
  String? mapsLink,
  String? contactName,
}) {
  final buf = StringBuffer()
    ..writeln('PRANA EMERGENCY ALERT')
    ..writeln()
    ..writeln(
      '${profile.name}, ${profile.age}, ${profile.gender}. '
      'Blood group ${profile.bloodGroup}.',
    )
    ..writeln('Raised at ${Fmt.clock(raisedAt)} on ${Fmt.date(raisedAt)}.')
    ..writeln();

  if (mapsLink != null) {
    buf
      ..writeln('Location: ${gpsText ?? 'see map link'}')
      ..writeln('Map: $mapsLink');
  } else if (gpsText != null && gpsText.isNotEmpty) {
    // Still resolving, or a status string rather than a fix.
    buf.writeln('Location: $gpsText');
  } else {
    buf.writeln('Location: not available — no location fix on this phone.');
  }

  buf
    ..writeln()
    ..writeln(
      profile.medicalConditions.isEmpty
          ? 'Medical notes: none on record.'
          : 'Medical notes: ${profile.medicalConditions.join(', ')}.',
    );

  if (hasLiveData) {
    buf
      ..writeln()
      ..writeln('From the band right now:')
      ..writeln('- Heart rate ${health.heartRate.toStringAsFixed(0)} BPM')
      ..writeln('- Blood oxygen ${health.spo2.toStringAsFixed(0)}%')
      ..writeln(
        '- Body temperature ${health.bodyTemperature.toStringAsFixed(1)} C',
      )
      ..writeln(
        '- PRANA risk score ${risk.overallScore} of 100 '
        '(${risk.level.displayName})',
      );
  } else {
    buf
      ..writeln()
      ..writeln('No band connected, so no vitals are available.');
  }

  buf
    ..writeln()
    ..write(
      contactName == null
          ? 'Sent automatically by PRANA on this phone.'
          : 'Sent automatically by PRANA to $contactName.',
    );

  return buf.toString();
}
