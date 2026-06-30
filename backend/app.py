from fastapi import FastAPI

from schemas import (
    MeasurementRequest,
    PredictionResponse,
)

from prediction_service import PredictionService

app = FastAPI(title="NetScope AI Backend")

service = PredictionService()


@app.get("/")
def root():
    return {"message": "Backend Running"}


@app.post(
    "/predict",
    response_model=PredictionResponse
)
def predict(data: MeasurementRequest):

    return service.predict(data)