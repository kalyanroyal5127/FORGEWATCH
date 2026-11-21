"""Secure local password reset utility; does not send email."""
import getpass
import sys
from werkzeug.security import generate_password_hash
from .database import connect, init_db, delete_user_tokens

def main():
    if len(sys.argv) != 2:
        print('Usage: python -m backend.reset_password USERNAME')
        raise SystemExit(2)
    username=sys.argv[1].strip()
    init_db()
    with connect() as db:
        user=db.execute('SELECT id FROM users WHERE username=?',(username,)).fetchone()
    if not user:
        print('No account found with that username.')
        raise SystemExit(1)
    password=getpass.getpass('New password (minimum 4 characters): ')
    confirm=getpass.getpass('Confirm new password: ')
    if len(password)<4 or password!=confirm:
        print('Passwords must match and contain at least 4 characters.')
        raise SystemExit(1)
    with connect() as db:
        db.execute('UPDATE users SET password_hash=? WHERE id=?',(generate_password_hash(password),user['id']))
    delete_user_tokens(user['id'])
    print('Password updated. Sign in again with the new password.')

if __name__=='__main__': main()
