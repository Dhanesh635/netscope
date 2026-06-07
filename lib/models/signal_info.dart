enum SignalInfoStatus {
  available,
  permissionDenied,
  unsupported,
  unavailable,
  error,
}

enum RadioTechnology {
  unknown('Unknown'),
  lte('LTE'),
  nr('5G NR');

  const RadioTechnology(this.displayName);
  final String displayName;
}

extension SignalInfoStatusDisplayName on SignalInfoStatus {
  String get displayName {
    switch (this) {
      case SignalInfoStatus.available:
        return 'available';
      case SignalInfoStatus.permissionDenied:
        return 'permissionDenied';
      case SignalInfoStatus.unsupported:
        return 'unsupported';
      case SignalInfoStatus.unavailable:
        return 'unavailable';
      case SignalInfoStatus.error:
        return 'error';
    }
  }
}

class SignalInfo {
  const SignalInfo({
    required this.status,
    this.technology = RadioTechnology.unknown,
    this.rsrp,
    this.rsrq,
    this.sinr,
    this.pci,
    this.carrier,
    this.message,
  });

  final SignalInfoStatus status;
  final RadioTechnology technology;
  final int? rsrp;
  final int? rsrq;
  final double? sinr;
  final int? pci;
  final String? carrier;
  final String? message;

  bool get hasSignalValues =>
      rsrp != null || rsrq != null || sinr != null || pci != null;

  Map<String, Object?> toMap() {
    return {
      'status': status.displayName,
      'technology': technology.name,
      'rsrp': rsrp,
      'rsrq': rsrq,
      'sinr': sinr,
      'pci': pci,
      'carrier': carrier,
      'message': message,
    };
  }

  factory SignalInfo.fromMap(Map<String, Object?> map) {
    return SignalInfo(
      status: _signalInfoStatusFromName(map['status'] as String?),
      technology: _radioTechnologyFromName(map['technology'] as String?),
      rsrp: (map['rsrp'] as num?)?.toInt(),
      rsrq: (map['rsrq'] as num?)?.toInt(),
      sinr: (map['sinr'] as num?)?.toDouble(),
      pci: (map['pci'] as num?)?.toInt(),
      carrier: map['carrier'] as String?,
      message: map['message'] as String?,
    );
  }
}

SignalInfoStatus _signalInfoStatusFromName(String? name) {
  switch (name) {
    case 'available':
      return SignalInfoStatus.available;
    case 'permissionDenied':
    case 'permission_denied':
      return SignalInfoStatus.permissionDenied;
    case 'unsupported':
      return SignalInfoStatus.unsupported;
    case 'unavailable':
      return SignalInfoStatus.unavailable;
    case 'error':
    default:
      return SignalInfoStatus.error;
  }
}

RadioTechnology _radioTechnologyFromName(String? name) {
  switch (name) {
    case 'lte':
      return RadioTechnology.lte;
    case 'nr':
      return RadioTechnology.nr;
    case 'unknown':
    default:
      return RadioTechnology.unknown;
  }
}
