import joblib

print("Loading ML model...")

model = joblib.load("handover_model.pkl")
scaler = joblib.load("scaler.pkl")

print("Model Loaded Successfully")
print("Classes:", model.classes_)