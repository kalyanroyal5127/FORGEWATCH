"""Explainable outputs and trend estimates for simulated sensor readings."""
from datetime import datetime, timedelta, timezone
import numpy as np

FEATURES = ('vibration', 'temperature', 'current')
UNITS = {'vibration': 'mm/s', 'temperature': '°C', 'current': 'A'}
NORMAL = {'vibration': 2.2, 'temperature': 58.0, 'current': 8.5}
SCALES = {'vibration': 1.1, 'temperature': 10.0, 'current': 2.5}

def explanation(reading, model_bundle):
    model = model_bundle['model']
    contributions = {name: float(model.feature_importances_[i]) * abs(float(reading[name])-NORMAL[name])/SCALES[name]
                     for i, name in enumerate(model_bundle['features'])}
    ranked = sorted(contributions.items(), key=lambda item:item[1], reverse=True)
    main = ranked[0][0]
    readable = {'vibration':'Vibration is furthest from its simulated baseline.',
                'temperature':'Temperature is furthest from its simulated baseline.',
                'current':'Electrical current is furthest from its simulated baseline.'}
    return {'sensor_contributions':contributions, 'primary_sensor':main, 'explanation':readable[main]}

def rul_estimate(machine_id, health, history_count, condition, degradation_pct=0):
    # Synthetic wear curve estimate; deliberately not calibrated to real equipment.
    remaining_fraction=max(0.01,1-float(degradation_pct)/100)
    wear_rate = 0.08 + max(0, 75-float(health))*0.018 + (0.8 if condition != 'Normal' else 0)
    days = round(max(1, min(365, (remaining_fraction*100/wear_rate) * 0.35)), 1)
    due = (datetime.now(timezone.utc) + timedelta(days=days)).isoformat(timespec='seconds')
    return {'rul_days_estimate':days, 'maintenance_due_estimate':due,
            'degradation_pct':round(float(degradation_pct),3),'degradation_samples':int(history_count), 'estimate_label':'SIMULATED ESTIMATE — NOT VALIDATED FOR INDUSTRIAL MAINTENANCE'}

def forecast(rows, steps=12):
    output={}
    for feature in FEATURES:
        values=np.asarray([float(r[feature]) for r in rows],dtype=float)
        if len(values)<2:
            output[feature]={'values':[], 'lower':[], 'upper':[], 'unit':UNITS[feature]}; continue
        x=np.arange(len(values),dtype=float); slope,intercept=np.polyfit(x,values,1)
        future_x=np.arange(len(values),len(values)+steps,dtype=float)
        predicted=intercept+slope*future_x
        resid=values-(intercept+slope*x); sigma=max(float(np.std(resid)),float(np.std(values))*0.03,0.01)
        widening=np.sqrt(1+np.arange(steps)/max(1,len(values)))
        margin=1.96*sigma*widening
        output[feature]={'values':predicted.round(3).tolist(),'lower':(predicted-margin).round(3).tolist(),
                         'upper':(predicted+margin).round(3).tolist(),'unit':UNITS[feature],
                         'slope_per_sample':round(float(slope),5),'method':'linear trend on simulated history'}
    return output
