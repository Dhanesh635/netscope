from pydantic import BaseModel


class MeasurementRequest(BaseModel):

    rsrp: float
    rsrq: float
    sinr: float | None = None

    download: float
    upload: float

    velocity: float

    latitude: float
    longitude: float


class PredictionResponse(BaseModel):

    handover_probability: float
    prediction: str
    confidence: float
    risk_level: str
    qos_score: float