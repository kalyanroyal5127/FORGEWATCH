"""Train and persist a synthetic Random Forest fault classifier."""
from pathlib import Path
import json
import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier, IsolationForest
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import train_test_split

ROOT = Path(__file__).resolve().parent
DATA = ROOT / 'data' / 'synthetic_sensor_readings.csv'
MODEL = ROOT / 'models' / 'fault_classifier.joblib'
ANOMALY_MODEL = ROOT / 'models' / 'isolation_forest.joblib'
METRICS = ROOT / 'models' / 'training_metrics.json'
FEATURES = ['vibration', 'temperature', 'current']

def train(data_path=DATA, model_path=MODEL):
    df = pd.read_csv(data_path)
    x, y = df[FEATURES], df['condition']
    xtr, xte, ytr, yte = train_test_split(x, y, test_size=.25, random_state=42, stratify=y)
    model = RandomForestClassifier(n_estimators=180, class_weight='balanced', random_state=42, n_jobs=-1)
    model.fit(xtr, ytr)
    anomaly = IsolationForest(n_estimators=200, contamination=0.04, random_state=42, n_jobs=1)
    anomaly.fit(xtr[ytr == 'Normal'])
    pred = model.predict(xte)
    labels = list(model.classes_)
    metrics = {'accuracy': accuracy_score(yte, pred), 'labels': labels,
               'feature_importance': {feature: float(value) for feature,value in zip(FEATURES,model.feature_importances_)},
               'confusion_matrix': confusion_matrix(yte, pred, labels=labels).tolist(),
               'classification_report': classification_report(yte, pred, output_dict=True, zero_division=0),
               'disclaimer': 'Evaluation uses synthetic data only; not industrial validation.'}
    model_path.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump({'model': model, 'features': FEATURES, 'labels': labels}, model_path)
    joblib.dump({'model': anomaly, 'features': FEATURES}, ANOMALY_MODEL)
    METRICS.write_text(json.dumps(metrics, indent=2), encoding='utf-8')
    print(f'Accuracy on synthetic holdout: {metrics["accuracy"]:.3f}; saved {model_path}')
    return metrics

if __name__ == '__main__':
    train()
