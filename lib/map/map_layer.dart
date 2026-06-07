enum MapLayer {
  signalStrength,
  sinr,
  downloadSpeed;

  String get label {
    switch (this) {
      case MapLayer.signalStrength:
        return 'Signal Strength';
      case MapLayer.sinr:
        return 'SINR';
      case MapLayer.downloadSpeed:
        return 'Download Speed';
    }
  }
}
