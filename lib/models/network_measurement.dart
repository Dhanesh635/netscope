class NetworkMeasurement {
	const NetworkMeasurement({
		this.id,
		this.sessionId,
		this.deviceId = '',
		this.deviceMake = '',
		this.deviceModel = '',
		required this.timestamp,
		required this.latitude,
		required this.longitude,
		required this.rsrp,
		required this.rsrq,
		this.sinr,
		required this.download,
		required this.upload,
		required this.pci,
		required this.carrier,
		required this.networkType,
		required this.velocity,
	});

	final int? id;
	final int? sessionId;
	final String deviceId;
	final String deviceMake;
	final String deviceModel;
	final DateTime timestamp;
	final double latitude;
	final double longitude;
	final double rsrp;
	final double rsrq;
	final double? sinr;
	final double download;
	final double upload;
	final int pci;
	final String carrier;
	final String networkType;
	final double velocity;

	Map<String, Object?> toMap() {
		double sanitize(double value, double fallback) {
			if (value.isNaN || value.isInfinite) return fallback;
			return value;
		}

		double? sanitizeNullable(double? value) {
			if (value == null) return null;
			if (value.isNaN || value.isInfinite) return null;
			return value;
		}

		final map = <String, Object?>{
			'session_id': sessionId,
			'device_id': deviceId,
			'device_make': deviceMake,
			'device_model': deviceModel,
			'timestamp': timestamp.millisecondsSinceEpoch,
			'latitude': sanitize(latitude, 0.0),
			'longitude': sanitize(longitude, 0.0),
			'rsrp': sanitize(rsrp, -140.0),
			'rsrq': sanitize(rsrq, -20.0),
			'sinr': sanitizeNullable(sinr),
			'download': sanitize(download, 0.0),
			'upload': sanitize(upload, 0.0),
			'pci': pci,
			'carrier': carrier,
			'network_type': networkType,
			'velocity': sanitize(velocity, 0.0),
		};
		if (id != null) {
			map['id'] = id;
		}
		return map;
	}

  factory NetworkMeasurement.fromMap(Map<dynamic, dynamic> map) {
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    double parseDouble(dynamic value, double fallback) {
      if (value == null) return fallback;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
      return fallback;
    }

    double? parseDoubleNullable(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return NetworkMeasurement(
      id: parseInt(map['id']),
      sessionId: parseInt(map['session_id']),
      deviceId: map['device_id']?.toString() ?? '',
      deviceMake: map['device_make']?.toString() ?? '',
      deviceModel: map['device_model']?.toString() ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(parseInt(map['timestamp']) ?? DateTime.now().millisecondsSinceEpoch),
      latitude: parseDouble(map['latitude'], 0.0),
      longitude: parseDouble(map['longitude'], 0.0),
      rsrp: parseDouble(map['rsrp'], -140.0),
      rsrq: parseDouble(map['rsrq'], -20.0),
      sinr: parseDoubleNullable(map['sinr']),
      download: parseDouble(map['download'], 0.0),
      upload: parseDouble(map['upload'], 0.0),
      pci: parseInt(map['pci']) ?? 0,
      carrier: map['carrier']?.toString() ?? 'UNKNOWN',
      networkType: map['network_type']?.toString() ?? 'UNKNOWN',
      velocity: parseDouble(map['velocity'], 0.0),
    );
  }
}
