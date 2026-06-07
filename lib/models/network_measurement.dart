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
		required this.sinr,
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
	final double sinr;
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
			'sinr': sanitize(sinr, -10.0),
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

	factory NetworkMeasurement.fromMap(Map<String, Object?> map) {
		return NetworkMeasurement(
			id: map['id'] as int?,
			sessionId: map['session_id'] as int?,
			deviceId: map['device_id'] as String? ?? '',
			deviceMake: map['device_make'] as String? ?? '',
			deviceModel: map['device_model'] as String? ?? '',
			timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
			latitude: (map['latitude'] as num).toDouble(),
			longitude: (map['longitude'] as num).toDouble(),
			rsrp: (map['rsrp'] as num).toDouble(),
			rsrq: (map['rsrq'] as num).toDouble(),
			sinr: (map['sinr'] as num).toDouble(),
			download: (map['download'] as num).toDouble(),
			upload: (map['upload'] as num).toDouble(),
			pci: map['pci'] as int,
			carrier: map['carrier'] as String,
			networkType: map['network_type'] as String,
			velocity: (map['velocity'] as num).toDouble(),
		);
	}
}
