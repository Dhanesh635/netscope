from model_loader import model, scaler
from feature_engineering import FeatureEngineer


class PredictionService:

    def __init__(self):
        self.engineer = FeatureEngineer()

    def predict(self, measurement):

        features, qos = self.engineer.build_features(measurement)

        import pandas as pd

        columns = [
            "RSRP",
            "RSRQ",
            "SINR",
            "download",
            "upload",
            "velocity",
            "latitude",
            "longitude",
            "RSRP_diff",
            "RSRQ_diff",
            "SINR_diff",
            "QoS_Score",
        ]

        features_df = pd.DataFrame(features, columns=columns)

        scaled = scaler.transform(features_df)
        prediction = int(model.predict(scaled)[0])

        probability = model.predict_proba(scaled)[0]

        print("Prediction:", prediction)
        print("Probability:", probability)

        confidence = float(max(probability))
        handover_probability = float(probability[1])

        if handover_probability < 0.30:
            risk = "Low"
        elif handover_probability < 0.60:
            risk = "Medium"
        elif handover_probability < 0.80:
            risk = "High"
        else:
            risk = "Critical"

        return {
            "handover_probability": round(handover_probability, 4),
            "prediction": "Handover" if prediction == 1 else "No Handover",
            "confidence": round(confidence, 4),
            "risk_level": risk,
            "qos_score": round(qos, 4),
        }