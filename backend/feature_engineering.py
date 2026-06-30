import numpy as np


class FeatureEngineer:

    def __init__(self):
        self.previous = None

    @staticmethod
    def _normalize(value, minimum, maximum):
        value = max(minimum, min(maximum, value))
        return (value - minimum) / (maximum - minimum)

    def calculate_qos(self, rsrp, rsrq, sinr, download, upload):

        sinr = 0 if sinr is None else sinr

        rsrp_n = self._normalize(rsrp, -140, -70)
        rsrq_n = self._normalize(rsrq, -20, -3)
        sinr_n = self._normalize(sinr, -10, 30)
        download_n = self._normalize(download, 0, 500)
        upload_n = self._normalize(upload, 0, 100)

        qos = (
            0.30 * sinr_n +
            0.25 * rsrp_n +
            0.20 * rsrq_n +
            0.15 * download_n +
            0.10 * upload_n
        )

        return qos

    def build_features(self, measurement):

        rsrp = measurement.rsrp
        rsrq = measurement.rsrq
        sinr = measurement.sinr if measurement.sinr is not None else 0

        if self.previous is None:

            rsrp_diff = 0
            rsrq_diff = 0
            sinr_diff = 0

        else:

            rsrp_diff = rsrp - self.previous["rsrp"]
            rsrq_diff = rsrq - self.previous["rsrq"]
            sinr_diff = sinr - self.previous["sinr"]

        self.previous = {
            "rsrp": rsrp,
            "rsrq": rsrq,
            "sinr": sinr
        }

        qos = self.calculate_qos(
            rsrp,
            rsrq,
            sinr,
            measurement.download,
            measurement.upload
        )

        return np.array([[
            rsrp,
            rsrq,
            sinr,
            measurement.download,
            measurement.upload,
            measurement.velocity,
            measurement.latitude,
            measurement.longitude,
            rsrp_diff,
            rsrq_diff,
            sinr_diff,
            qos
        ]]), qos