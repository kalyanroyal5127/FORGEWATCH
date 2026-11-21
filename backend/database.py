"""SQLite persistence helpers for virtual machines and sensor events."""
import sqlite3
import os
from datetime import timedelta
from pathlib import Path
from datetime import datetime, timezone

DB_PATH = Path(os.environ.get('FORGEWATCH_DB_PATH', Path(__file__).resolve().parent / 'data' / 'machine_monitor.db'))

class ManagedConnection(sqlite3.Connection):
    def __exit__(self, exc_type, exc, traceback):
        try:
            return super().__exit__(exc_type, exc, traceback)
        finally:
            self.close()

def connect():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(DB_PATH, timeout=10, factory=ManagedConnection)
    db.row_factory = sqlite3.Row
    return db

def init_db():
    with connect() as db:
        db.executescript('''
        CREATE TABLE IF NOT EXISTS machines (machine_id TEXT PRIMARY KEY, name TEXT NOT NULL, created_at TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS readings (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp TEXT NOT NULL, machine_id TEXT NOT NULL, vibration REAL NOT NULL, temperature REAL NOT NULL, current REAL NOT NULL, condition TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS predictions (id INTEGER PRIMARY KEY AUTOINCREMENT, reading_id INTEGER NOT NULL, condition TEXT NOT NULL, confidence REAL NOT NULL, health REAL NOT NULL, severity TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS alerts (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp TEXT NOT NULL, machine_id TEXT NOT NULL, condition TEXT NOT NULL, severity TEXT NOT NULL, message TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS api_tokens (token_hash TEXT PRIMARY KEY, user_id INTEGER NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE);
        CREATE TABLE IF NOT EXISTS login_attempts (attempt_key TEXT PRIMARY KEY, failures INTEGER NOT NULL DEFAULT 0, window_start TEXT NOT NULL, locked_until TEXT);
        CREATE TABLE IF NOT EXISTS password_reset_tokens (token_hash TEXT PRIMARY KEY,user_id INTEGER NOT NULL,expires_at TEXT NOT NULL,used INTEGER NOT NULL DEFAULT 0,FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE);
        CREATE TABLE IF NOT EXISTS maintenance (id INTEGER PRIMARY KEY AUTOINCREMENT,machine_id TEXT NOT NULL,due_at TEXT NOT NULL,kind TEXT NOT NULL,status TEXT NOT NULL DEFAULT 'Scheduled',notes TEXT NOT NULL DEFAULT '',created_at TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS maintenance_history (id INTEGER PRIMARY KEY AUTOINCREMENT,machine_id TEXT NOT NULL,service_at TEXT NOT NULL,kind TEXT NOT NULL,notes TEXT NOT NULL,performed_by TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS notifications (id INTEGER PRIMARY KEY AUTOINCREMENT,user_id INTEGER,timestamp TEXT NOT NULL,kind TEXT NOT NULL,severity TEXT NOT NULL,message TEXT NOT NULL,read INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE IF NOT EXISTS simulation_events (id INTEGER PRIMARY KEY AUTOINCREMENT,machine_id TEXT NOT NULL,timestamp TEXT NOT NULL,event TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS alert_actions (alert_id INTEGER PRIMARY KEY,status TEXT NOT NULL DEFAULT 'Open',acknowledged_by TEXT,resolved_by TEXT,updated_at TEXT);
        ''')
        # Additive migrations preserve existing local databases.
        users_need_role_migration = 'role' not in {
            row['name'] for row in db.execute('PRAGMA table_info(users)')
        }
        for table, column, declaration in [('users','role',"TEXT NOT NULL DEFAULT 'Operator'"),
                                           ('users','email','TEXT'),
                                           ('api_tokens','expires_at','TEXT'),
                                           ('readings','anomaly_score','REAL NOT NULL DEFAULT 0'),
                                           ('readings','is_anomaly','INTEGER NOT NULL DEFAULT 0'),
                                           ('readings','primary_sensor',"TEXT NOT NULL DEFAULT ''"),
                                           ('readings','rul_days_estimate','REAL NOT NULL DEFAULT 0'),
                                           ('readings','degradation_pct','REAL NOT NULL DEFAULT 0'),
                                           ('alerts','status',"TEXT NOT NULL DEFAULT 'Open'"),
                                           ('alerts','acknowledged_by','TEXT'),
                                           ('alerts','resolved_by','TEXT'),
                                           ('alerts','updated_at','TEXT')]:
            present={row['name'] for row in db.execute(f'PRAGMA table_info({table})')}
            if column not in present:
                db.execute(f'ALTER TABLE {table} ADD COLUMN {column} {declaration}')
        # Preserve the historical first-admin migration only for databases that
        # are receiving the role column for the first time.
        if users_need_role_migration:
            db.execute("UPDATE users SET role='Admin' WHERE id=(SELECT MIN(id) FROM users) AND role='Operator'")
        # Backfill events created before notification records were introduced.
        db.execute('''INSERT INTO notifications(timestamp,kind,severity,message)
                      SELECT a.timestamp,'Fault',a.severity,a.message FROM alerts a
                      WHERE NOT EXISTS (SELECT 1 FROM notifications n
                                        WHERE n.kind='Fault' AND n.timestamp=a.timestamp AND n.message=a.message)''')

def create_user(username, password_hash, role='Operator', email=None):
    with connect() as db:
        cur = db.execute('INSERT INTO users(username,password_hash,role,email) VALUES(?,?,?,?)', (username, password_hash, role,email))
        return cur.lastrowid

def find_user(username):
    with connect() as db:
        row = db.execute('SELECT * FROM users WHERE username=? OR lower(email)=lower(?)', (username,username)).fetchone()
        return dict(row) if row else None

def save_token(token_hash, user_id):
    with connect() as db:
        now=datetime.now(timezone.utc)
        db.execute('INSERT INTO api_tokens(token_hash,user_id,created_at,expires_at) VALUES(?,?,?,?)',
                   (token_hash, user_id, now.isoformat(),(now+timedelta(days=30)).isoformat()))

def token_user(token_hash):
    with connect() as db:
        row = db.execute('SELECT u.id,u.username,u.role FROM api_tokens t JOIN users u ON u.id=t.user_id WHERE t.token_hash=? AND (t.expires_at IS NULL OR t.expires_at>?)', (token_hash,datetime.now(timezone.utc).isoformat())).fetchone()
        return dict(row) if row else None

def delete_token(token_hash):
    with connect() as db:
        db.execute('DELETE FROM api_tokens WHERE token_hash=?', (token_hash,))

def delete_user_tokens(user_id):
    with connect() as db:
        db.execute('DELETE FROM api_tokens WHERE user_id=?', (user_id,))

def record_login_failure(attempt_key, window_minutes=5, max_delay=2.0):
    """Record a failed sign-in and return a bounded delay; never lock the account or IP."""
    now=datetime.now(timezone.utc)
    with connect() as db:
        row=db.execute('SELECT * FROM login_attempts WHERE attempt_key=?',(attempt_key,)).fetchone()
        if not row or datetime.fromisoformat(row['window_start'])<now-timedelta(minutes=window_minutes):
            failures=1; start=now.isoformat()
        else: failures=row['failures']+1; start=row['window_start']
        db.execute('INSERT OR REPLACE INTO login_attempts VALUES(?,?,?,NULL)',(attempt_key,failures,start))
        return min(max_delay, 0.25 * (2 ** min(failures-1, 3)))

def clear_login_failures(attempt_key):
    with connect() as db: db.execute('DELETE FROM login_attempts WHERE attempt_key=?',(attempt_key,))

def save_reading(item, prediction):
    with connect() as db:
        db.execute('INSERT OR IGNORE INTO machines VALUES(?,?,?)', (item['machine_id'], item['machine_name'], datetime.now(timezone.utc).isoformat()))
        cur = db.execute('INSERT INTO readings(timestamp,machine_id,vibration,temperature,current,condition,anomaly_score,is_anomaly,primary_sensor,rul_days_estimate,degradation_pct) VALUES(?,?,?,?,?,?,?,?,?,?,?)', (item['timestamp'],item['machine_id'],item['vibration'],item['temperature'],item['current'],prediction['condition'],prediction.get('anomaly_score',0),int(prediction.get('is_anomaly',False)),prediction.get('primary_sensor',''),prediction.get('rul_days_estimate',0),item.get('degradation_pct',0)))
        db.execute('INSERT INTO predictions(reading_id,condition,confidence,health,severity) VALUES(?,?,?,?,?)', (cur.lastrowid,prediction['condition'],prediction['confidence'],prediction['health'],prediction['severity']))
        if prediction['condition'] != 'Normal':
            active=db.execute("SELECT id FROM alerts WHERE machine_id=? AND condition=? AND status!='Resolved' ORDER BY id DESC LIMIT 1",(item['machine_id'],prediction['condition'])).fetchone()
            if not active:
                alert=db.execute('INSERT INTO alerts(timestamp,machine_id,condition,severity,message,status) VALUES(?,?,?,?,?,?)',(item['timestamp'],item['machine_id'],prediction['condition'],prediction['severity'],f"{item['machine_name']}: {prediction['condition']}",'Open'))
                db.execute('INSERT INTO notifications(timestamp,kind,severity,message) VALUES(?,?,?,?)',(item['timestamp'],'Fault',prediction['severity'],f"{item['machine_name']}: {prediction['condition']}"))
        return cur.lastrowid
