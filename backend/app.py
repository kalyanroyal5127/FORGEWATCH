"""Flask API for the simulated machine health demonstration."""
from flask import Flask, jsonify, request, Response, send_from_directory, redirect, session, g, send_file
from flask_cors import CORS
from pathlib import Path
import csv, io, json, threading, os, secrets, hashlib, time
from functools import wraps
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.middleware.proxy_fix import ProxyFix
import joblib
import pandas as pd
from .database import (init_db, save_reading, connect, create_user, find_user, save_token, token_user,
                       delete_token, delete_user_tokens, record_login_failure,
                       clear_login_failures)
from .simulator import SensorSimulator
from .train_model import train, MODEL, METRICS, ANOMALY_MODEL
from .advanced import explanation, rul_estimate, forecast, FEATURES

ROOT = Path(__file__).resolve().parent
WEB = ROOT.parent / 'web'
app = Flask(__name__, static_folder=None)
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1)
CORS(app)
secret_path=ROOT / 'data' / 'session_secret.key'
secret_path.parent.mkdir(parents=True,exist_ok=True)
if os.environ.get('FORGEWATCH_SECRET_KEY'):
    app.secret_key=os.environ['FORGEWATCH_SECRET_KEY']
else:
    if not secret_path.exists(): secret_path.write_text(secrets.token_hex(48),encoding='ascii')
    app.secret_key=secret_path.read_text(encoding='ascii').strip()
app.config.update(SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE='Lax',
                  SESSION_COOKIE_SECURE=(os.environ.get('RENDER', '').lower() == 'true'
                                         or os.environ.get('FORGEWATCH_HTTPS_ONLY', '').lower() == 'true'),
                  PERMANENT_SESSION_LIFETIME=__import__('datetime').timedelta(hours=12))
lock = threading.Lock()
simulator = SensorSimulator(machines=5)
try:
    bundle = joblib.load(MODEL)
except FileNotFoundError:
    train()
    bundle = joblib.load(MODEL)
model = bundle['model']
if not ANOMALY_MODEL.exists(): train()
anomaly_bundle=joblib.load(ANOMALY_MODEL)
anomaly_model=anomaly_bundle['model']
anomaly_model.set_params(n_jobs=1)
init_db()

def bootstrap_admin_from_environment():
    """Create the first production admin from Render environment secrets, once."""
    username=os.environ.get('FORGEWATCH_ADMIN_USERNAME','').strip()
    password=os.environ.get('FORGEWATCH_ADMIN_PASSWORD','')
    if not username and not password:
        return
    with connect() as db:
        if db.execute("SELECT 1 FROM users WHERE role='Admin' LIMIT 1").fetchone():
            return
    if len(username)<3 or len(username)>32 or not username.replace('_','').isalnum() or len(password)<4:
        raise RuntimeError('Set a valid FORGEWATCH_ADMIN_USERNAME and a FORGEWATCH_ADMIN_PASSWORD of at least 4 characters.')
    password_hash=generate_password_hash(password)
    with connect() as db:
        if db.execute("SELECT 1 FROM users WHERE role='Admin' LIMIT 1").fetchone():
            return
        existing=db.execute('SELECT id FROM users WHERE username=?',(username,)).fetchone()
        if existing:
            db.execute("UPDATE users SET role='Admin',password_hash=? WHERE id=?",(password_hash,existing['id']))
        else:
            db.execute('INSERT INTO users(username,password_hash,role) VALUES(?,?,?)',(username,password_hash,'Admin'))

bootstrap_admin_from_environment()
simulation_state={'running':True,'stopped':False,'started_at':None}

@app.before_request
def require_api_authentication():
    if not request.path.startswith('/api/') or request.path in ('/api/health', '/api/auth/login', '/api/auth/register'):
        return None
    user = None
    auth = request.headers.get('Authorization', '')
    if auth.startswith('Bearer '):
        user = token_user(hashlib.sha256(auth[7:].encode()).hexdigest())
    if not user and session.get('user_id'):
        user = {'id': session['user_id'], 'username': session.get('username', ''), 'role': session.get('role','Operator')}
    if not user:
        return jsonify({'error': 'Authentication required', 'login': '/login'}), 401
    g.user = user

def roles_required(*roles):
    def decorate(fn):
        @wraps(fn)
        def wrapped(*args,**kwargs):
            if g.user.get('role') not in roles: return jsonify({'error':'Insufficient role permissions'}),403
            return fn(*args,**kwargs)
        return wrapped
    return decorate

@app.get('/login')
def login_page():
    if session.get('user_id'): return redirect('/')
    return send_from_directory(WEB, 'login.html')

@app.get('/register')
def register_page(): return send_from_directory(WEB, 'register.html')

@app.get('/forgot-password')
def forgot_password_page(): return send_from_directory(WEB,'forgot-password.html')

@app.get('/logout')
def logout_page():
    if session.get('user_id'): delete_user_tokens(session['user_id'])
    session.clear()
    return redirect('/login')

@app.post('/api/auth/register')
def register():
    body=request.get_json(silent=True) or {}
    username=str(body.get('username','')).strip()
    password=str(body.get('password',''))
    if len(username)<3 or len(username)>32 or not username.replace('_','').isalnum():
        return jsonify({'error':'Username must be 3–32 letters, numbers, or underscores.'}),400
    if len(password)<4:
        return jsonify({'error':'Password must contain at least 4 characters.'}),400
    email=str(body.get('email','')).strip() or None
    if email and ('@' not in email or len(email)>254): return jsonify({'error':'Enter a valid email address.'}),400
    role='Operator'
    if os.environ.get('RENDER','').lower() != 'true':
        with connect() as db:
            if db.execute('SELECT COUNT(*) FROM users').fetchone()[0] == 0: role='Admin'
    try: create_user(username, generate_password_hash(password), role=role, email=email)
    except Exception:
        return jsonify({'error':'That username is already registered.'}),409
    return jsonify({'message':'Account created. You can now sign in.'}),201

@app.post('/api/auth/login')
def authenticate():
    body=request.get_json(silent=True) or {}
    identity=str(body.get('identity',body.get('username',''))).strip()
    attempt_key=hashlib.sha256(str(request.remote_addr or 'unknown').encode()).hexdigest()
    user=find_user(identity)
    password=str(body.get('password',''))
    if not user or not check_password_hash(user['password_hash'],password):
        # Slow repeated failures without rejecting attempts. A valid password takes
        # the success path immediately, regardless of the prior failure count.
        time.sleep(record_login_failure(attempt_key))
        return jsonify({'error':'Incorrect username/email or password.'}),401
    clear_login_failures(attempt_key)
    session.clear(); session['user_id']=user['id']; session['username']=user['username']; session['role']=user['role']
    session.permanent=bool(body.get('remember',False))
    raw=secrets.token_urlsafe(32); save_token(hashlib.sha256(raw.encode()).hexdigest(),user['id'])
    return jsonify({'message':'Signed in','username':user['username'],'role':user['role'],'token':raw})

@app.post('/api/auth/logout')
def logout():
    auth=request.headers.get('Authorization','')
    if auth.startswith('Bearer '): delete_token(hashlib.sha256(auth[7:].encode()).hexdigest())
    session.clear()
    return jsonify({'message':'Signed out'})

@app.get('/api/auth/me')
def current_user(): return jsonify({'username':g.user['username'],'role':g.user.get('role','Operator')})

def classify(item):
    features = pd.DataFrame([[item['vibration'], item['temperature'], item['current']]],
                            columns=bundle['features'])
    probs = model.predict_proba(features)[0]
    idx = int(probs.argmax()); condition = str(model.classes_[idx]); confidence = float(probs[idx])
    health = round(max(0, min(100, 100 - confidence * (0 if condition == 'Normal' else 45) - (0 if condition == 'Normal' else 20))), 1)
    severity = 'Low' if condition == 'Normal' else ('Critical' if confidence > .85 else 'Warning')
    score=float(-anomaly_model.decision_function(features)[0])
    anomalous=bool(anomaly_model.predict(features)[0] == -1)
    explain=explanation(item,bundle)
    with connect() as db:
        count=db.execute('SELECT COUNT(*) FROM readings WHERE machine_id=?',(item['machine_id'],)).fetchone()[0]
    rul=rul_estimate(item['machine_id'],health,count,condition,item.get('degradation_pct',0))
    return {'condition':condition,'confidence':round(confidence,4),'health':health,'severity':severity,
            'anomaly_score':round(score,5),'is_anomaly':anomalous,**explain,**rul}

def latest_items():
    with connect() as db:
        return [dict(r) for r in db.execute('''SELECT r.*,p.condition AS prediction,p.confidence,p.health,p.severity FROM readings r JOIN predictions p ON p.reading_id=r.id WHERE r.id IN (SELECT MAX(id) FROM readings GROUP BY machine_id) ORDER BY r.machine_id''')]

@app.get('/')
def index():
    if not session.get('user_id'): return redirect('/login')
    return send_from_directory(WEB, 'index.html')

@app.get('/overview')
def overview():
    """Support a conventional dashboard URL while retaining the single-page UI."""
    return index()

@app.get('/<path:path>')
def static(path): return send_from_directory(WEB, path)
@app.get('/api/health')
def health(): return jsonify({'status':'ok','mode':'simulated data','model_loaded':True})
@app.get('/api/metrics')
def metrics(): return jsonify(json.loads(METRICS.read_text(encoding='utf-8')))
@app.get('/api/machines')
def machines(): return jsonify(latest_items())
@app.get('/api/snapshot')
def snapshot():
    if not simulation_state['running']:
        return jsonify({'paused':True,'stopped':simulation_state['stopped'],'machines':latest_items()})
    with lock:
        readings=simulator.sample()
        result=[]
        for item in readings:
            pred=classify(item); save_reading(item,pred); result.append({**item,**pred})
    return jsonify({'timestamp':result[0]['timestamp'],'machines':result})
@app.get('/api/history')
def history():
    machine=request.args.get('machine_id'); limit=max(1,min(500,int(request.args.get('limit',100))))
    with connect() as db:
        rows=db.execute('SELECT * FROM readings '+('WHERE machine_id=? ' if machine else '')+'ORDER BY id DESC LIMIT ?', ((machine,limit) if machine else (limit,)))
        return jsonify([dict(r) for r in reversed(rows.fetchall())])
@app.get('/api/alerts')
def alerts():
    query=request.args.get('q','').strip(); severity=request.args.get('severity','').strip(); status=request.args.get('status','').strip()
    sql='SELECT * FROM alerts WHERE 1=1'; params=[]
    if query: sql+=' AND (machine_id LIKE ? OR condition LIKE ? OR message LIKE ?)'; params += [f'%{query}%']*3
    if severity: sql+=' AND severity=?'; params.append(severity)
    if status: sql+=' AND status=?'; params.append(status)
    sql+=' ORDER BY id DESC LIMIT 250'
    with connect() as db: return jsonify([dict(r) for r in db.execute(sql,params)])

@app.post('/api/alerts/<int:alert_id>/action')
def alert_action(alert_id):
    body=request.get_json(silent=True) or {}; action=body.get('action')
    if action not in ('acknowledge','resolve'): return jsonify({'error':'action must be acknowledge or resolve'}),400
    state='Acknowledged' if action=='acknowledge' else 'Resolved'; stamp=__import__('datetime').datetime.now(__import__('datetime').timezone.utc).isoformat()
    with connect() as db:
        row=db.execute('SELECT id FROM alerts WHERE id=?',(alert_id,)).fetchone()
        if not row: return jsonify({'error':'Alert not found'}),404
        db.execute('UPDATE alerts SET status=?,acknowledged_by=CASE WHEN ?="Acknowledged" THEN ? ELSE acknowledged_by END,resolved_by=CASE WHEN ?="Resolved" THEN ? ELSE resolved_by END,updated_at=? WHERE id=?',(state,state,g.user['username'],state,g.user['username'],stamp,alert_id))
    return jsonify({'id':alert_id,'status':state})
@app.get('/api/reports.csv')
def report():
    with connect() as db: rows=db.execute('SELECT * FROM readings ORDER BY id DESC LIMIT 5000').fetchall()
    out=io.StringIO(); writer=csv.writer(out); writer.writerow(rows[0].keys() if rows else ['id','timestamp','machine_id','vibration','temperature','current','condition'])
    writer.writerows([tuple(r) for r in rows]); return Response(out.getvalue(), mimetype='text/csv', headers={'Content-Disposition':'attachment; filename=machine_report.csv'})
@app.post('/api/settings')
@roles_required('Admin','Engineer')
def settings():
    global simulator
    body=request.get_json(silent=True) or {}
    try:
        count=int(body.get('machines',len(simulator.machines))); probability=float(body.get('fault_probability',simulator.fault_probability))
        fresh=SensorSimulator(count, fault_probability=probability)
    except (TypeError,ValueError) as exc: return jsonify({'error':str(exc)}),400
    with lock: simulator=fresh
    return jsonify({'machines':count,'fault_probability':probability})

@app.post('/api/simulation/control')
@roles_required('Admin','Engineer')
def simulation_control():
    body=request.get_json(silent=True) or {}; action=body.get('action')
    if action in ('start','resume'):
        simulation_state.update(running=True,stopped=False)
    elif action=='pause': simulation_state['running']=False
    elif action=='stop': simulation_state.update(running=False,stopped=True)
    elif action=='reset':
        simulator.clear_faults(); simulation_state.update(running=True,stopped=False)
    elif action=='inject':
        try: simulator.inject_fault(str(body.get('machine_id','')),str(body.get('condition','')))
        except ValueError as exc: return jsonify({'error':str(exc)}),400
        with connect() as db: db.execute('INSERT INTO simulation_events(machine_id,timestamp,event) VALUES(?,?,?)',(body['machine_id'],__import__('datetime').datetime.now(__import__('datetime').timezone.utc).isoformat(),body['condition']))
    else: return jsonify({'error':'Unsupported control action'}),400
    return jsonify({'state':'running' if simulation_state['running'] else ('stopped' if simulation_state['stopped'] else 'paused'),'machines':len(simulator.machines)})

@app.get('/api/simulation/status')
def simulation_status(): return jsonify({'state':'running' if simulation_state['running'] else ('stopped' if simulation_state['stopped'] else 'paused'),'machines':[{'machine_id':m.machine_id,'name':m.name,'injected_condition':m.injected_condition} for m in simulator.machines]})

@app.get('/api/analysis/forecast')
def forecast_api():
    machine=request.args.get('machine_id'); limit=max(2,min(300,int(request.args.get('limit',60))))
    with connect() as db:
        rows=db.execute('SELECT timestamp,vibration,temperature,current FROM readings '+('WHERE machine_id=? ' if machine else '')+'ORDER BY id DESC LIMIT ?',((machine,limit) if machine else (limit,))).fetchall()
    records=[dict(x) for x in reversed(rows)]
    return jsonify({'machine_id':machine,'history':records,'forecast':forecast(records),'notice':'Forecasts use simulated history and are not validated future-failure estimates.'})

@app.get('/api/comparison')
def comparison():
    rows=latest_items()
    for index,row in enumerate(sorted(rows,key=lambda x:x['health'],reverse=True),1): row['rank']=index
    return jsonify(sorted(rows,key=lambda x:x['machine_id']))

@app.get('/api/analytics/oee')
def oee():
    with connect() as db:
        total=db.execute('SELECT COUNT(*) FROM readings').fetchone()[0]
        normal=db.execute("SELECT COUNT(*) FROM readings WHERE condition='Normal'").fetchone()[0]
        fault=db.execute("SELECT COUNT(*) FROM readings WHERE condition!='Normal'").fetchone()[0]
        downtime=db.execute("SELECT COUNT(DISTINCT machine_id || condition || substr(timestamp,1,16)) FROM alerts WHERE status!='Resolved'").fetchone()[0]
    quality=normal/max(1,total); performance=max(.5,min(1.0,1-fault/max(1,total)*.5)); availability=max(.5,1-min(.5,downtime/max(1,total)))
    return jsonify({'availability':round(availability*100,1),'performance':round(performance*100,1),'quality':round(quality*100,1),'oee':round(availability*performance*quality*100,1),'samples':total,'fault_samples':fault,'downtime_events':downtime,'label':'SIMULATED OEE INDEX — NOT INDUSTRIAL KPI VALIDATION'})

@app.route('/api/maintenance',methods=['GET','POST'])
def maintenance():
    if request.method=='GET':
        with connect() as db:
            upcoming=[dict(x) for x in db.execute("SELECT * FROM maintenance WHERE status='Scheduled' ORDER BY due_at LIMIT 100")]
            history=[dict(x) for x in db.execute('SELECT * FROM maintenance_history ORDER BY service_at DESC LIMIT 100')]
        return jsonify({'upcoming':upcoming,'history':history})
    if g.user['role'] not in ('Admin','Engineer'): return jsonify({'error':'Engineer or Admin role required'}),403
    body=request.get_json(silent=True) or {}; machine=str(body.get('machine_id','')); due=str(body.get('due_at','')); kind=str(body.get('kind','Inspection')); notes=str(body.get('notes',''))
    if machine not in {m.machine_id for m in simulator.machines}: return jsonify({'error':'Unknown machine'}),400
    try:
        from datetime import datetime
        datetime.fromisoformat(due.replace('Z','+00:00'))
    except ValueError: return jsonify({'error':'due_at must be an ISO-8601 timestamp'}),400
    with connect() as db:
        cur=db.execute("INSERT INTO maintenance(machine_id,due_at,kind,notes,created_at) VALUES(?,?,?,?,datetime('now'))",(machine,due,kind,notes))
        db.execute('INSERT INTO notifications(timestamp,kind,severity,message) VALUES(datetime(\'now\'),?,?,?)',('Maintenance','Info',f'{kind} scheduled for {machine} at {due}'))
    return jsonify({'id':cur.lastrowid,'status':'Scheduled'}),201

@app.post('/api/maintenance/<int:item_id>/complete')
def complete_maintenance(item_id):
    if g.user['role'] not in ('Admin','Engineer'): return jsonify({'error':'Engineer or Admin role required'}),403
    with connect() as db:
        row=db.execute('SELECT * FROM maintenance WHERE id=?',(item_id,)).fetchone()
        if not row: return jsonify({'error':'Maintenance item not found'}),404
        stamp=__import__('datetime').datetime.now(__import__('datetime').timezone.utc).isoformat()
        db.execute("UPDATE maintenance SET status='Completed' WHERE id=?",(item_id,))
        db.execute('INSERT INTO maintenance_history(machine_id,service_at,kind,notes,performed_by) VALUES(?,?,?,?,?)',(row['machine_id'],stamp,row['kind'],row['notes'],g.user['username']))
    return jsonify({'id':item_id,'status':'Completed'})

@app.get('/api/notifications')
def notifications():
    with connect() as db:
        # Existing alerts may predate notification support; expose them on the first read.
        db.execute('''INSERT INTO notifications(timestamp,kind,severity,message)
                      SELECT a.timestamp,'Fault',a.severity,a.message FROM alerts a
                      WHERE NOT EXISTS (SELECT 1 FROM notifications n
                                        WHERE n.kind='Fault' AND n.timestamp=a.timestamp AND n.message=a.message)''')
        return jsonify([dict(x) for x in db.execute('SELECT * FROM notifications WHERE user_id IS NULL OR user_id=? ORDER BY id DESC LIMIT 100',(g.user['id'],))])

@app.post('/api/notifications/<int:item_id>/read')
def notification_read(item_id):
    with connect() as db: db.execute('UPDATE notifications SET read=1 WHERE id=? AND (user_id IS NULL OR user_id=?)',(item_id,g.user['id']))
    return jsonify({'id':item_id,'read':True})

@app.get('/api/users')
@roles_required('Admin')
def users():
    with connect() as db: return jsonify([dict(x) for x in db.execute('SELECT id,username,role FROM users ORDER BY username')])

@app.patch('/api/users/<int:user_id>/role')
@roles_required('Admin')
def user_role(user_id):
    role=(request.get_json(silent=True) or {}).get('role')
    if role not in ('Admin','Engineer','Operator'): return jsonify({'error':'Role must be Admin, Engineer, or Operator'}),400
    with connect() as db:
        if not db.execute('SELECT id FROM users WHERE id=?',(user_id,)).fetchone(): return jsonify({'error':'User not found'}),404
        db.execute('UPDATE users SET role=? WHERE id=?',(role,user_id))
    return jsonify({'id':user_id,'role':role})

@app.get('/api/reports.xlsx')
def report_xlsx():
    from openpyxl import Workbook
    with connect() as db:
        rows=[dict(r) for r in db.execute('SELECT * FROM readings ORDER BY id DESC LIMIT 5000')]
        summary=[dict(r) for r in db.execute('SELECT machine_id,COUNT(*) samples,ROUND(AVG(vibration),3) avg_vibration,ROUND(MAX(temperature),2) max_temperature,ROUND(AVG(current),3) avg_current,SUM(CASE WHEN condition!=\'Normal\' THEN 1 ELSE 0 END) fault_samples FROM readings GROUP BY machine_id')]
    book=Workbook(); sheet=book.active; sheet.title='Sensor readings'
    keys=list(rows[0]) if rows else ['id','timestamp','machine_id','vibration','temperature','current','condition']
    sheet.append(keys)
    for row in rows: sheet.append([row[k] for k in keys])
    sheet.freeze_panes='A2'; sheet.auto_filter.ref=sheet.dimensions
    stats=book.create_sheet('Machine statistics')
    stats.append(list(summary[0]) if summary else ['machine_id','samples','avg_vibration','max_temperature','avg_current','fault_samples'])
    for row in summary: stats.append(list(row.values()))
    alerts_sheet=book.create_sheet('Fault history'); alerts_sheet.append(['timestamp','machine_id','condition','severity','status','message'])
    with connect() as db:
        for row in db.execute('SELECT timestamp,machine_id,condition,severity,status,message FROM alerts ORDER BY id DESC LIMIT 1000'): alerts_sheet.append(list(row))
    buffer=io.BytesIO(); book.save(buffer); buffer.seek(0)
    return send_file(buffer,as_attachment=True,download_name='machine_fault_detection_report.xlsx',mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

@app.get('/api/reports.pdf')
def report_pdf():
    from reportlab.lib.pagesizes import letter
    from reportlab.pdfgen import canvas
    with connect() as db:
        rows=[dict(r) for r in db.execute('SELECT * FROM readings ORDER BY id DESC LIMIT 5000')]
        stats=[dict(r) for r in db.execute('SELECT machine_id,COUNT(*) samples,ROUND(AVG(vibration),2) vibration,ROUND(AVG(temperature),2) temperature,ROUND(AVG(current),2) current,SUM(CASE WHEN condition!=\'Normal\' THEN 1 ELSE 0 END) faults FROM readings GROUP BY machine_id')]
        fault_rows=[dict(r) for r in db.execute('SELECT timestamp,machine_id,condition,severity,status FROM alerts ORDER BY id DESC LIMIT 30')]
    buffer=io.BytesIO(); pdf=canvas.Canvas(buffer,pagesize=letter); width,height=letter
    pdf.setTitle('Machine Learning-Based Fault Detection and Prediction System')
    pdf.drawString(45,height-45,'MACHINE LEARNING-BASED FAULT DETECTION AND PREDICTION SYSTEM')
    pdf.drawString(45,height-65,'SIMULATED MACHINE CONDITION REPORT')
    pdf.drawString(45,height-80,f"Generated {__import__('datetime').datetime.now().isoformat(timespec='minutes')} · Not industrial validation")
    y=height-112
    pdf.setFont('Helvetica-Bold',10); pdf.drawString(45,y,'MACHINE SENSOR SUMMARY'); y-=18; pdf.setFont('Helvetica',8)
    for r in stats:
        pdf.drawString(45,y,f"{r['machine_id']} | n={r['samples']} | avg vibration {r['vibration']} | avg temp {r['temperature']} | avg current {r['current']} | fault samples {r['faults']}"); y-=12
    y-=12; pdf.setFont('Helvetica-Bold',10); pdf.drawString(45,y,'RECENT FAULT HISTORY'); y-=18; pdf.setFont('Helvetica',8)
    for r in fault_rows[:12]:
        pdf.drawString(45,y,f"{r['timestamp']} | {r['machine_id']} | {r['condition']} | {r['severity']} | {r['status']}"); y-=12
        if y<75: pdf.showPage(); y=height-45
    y-=10; pdf.setFont('Helvetica-Bold',10); pdf.drawString(45,y,'LATEST SENSOR READINGS'); y-=18; pdf.setFont('Helvetica',8)
    for row in rows[:45]:
        pdf.drawString(45,y,f"{row['timestamp']}  {row['machine_id']}  Vib {row['vibration']}  Temp {row['temperature']}  Current {row['current']}  {row['condition']}")
        y-=14
        if y<45: pdf.showPage(); y=height-45
    pdf.save(); buffer.seek(0)
    return send_file(buffer,as_attachment=True,download_name='machine_fault_detection_report.pdf',mimetype='application/pdf')

if __name__ == '__main__': app.run(host='0.0.0.0',port=int(os.environ.get('PORT', '5000')),debug=False)
