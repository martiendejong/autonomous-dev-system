#!/usr/bin/env python3
"""Check if admin account exists in the database"""

import paramiko

SSH_HOST = "85.215.217.154"
SSH_USER = "administrator"
SSH_PASSWORD = "3WsXcFr$7YhNmKi*"

def check_admin():
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(SSH_HOST, username=SSH_USER, password=SSH_PASSWORD)

        # Check if database has users
        command = r'powershell -Command "& {sqlite3.exe C:\stores\brand2boost\data\identity.db \"SELECT UserName, Email FROM AspNetUsers;\"}"'

        stdin, stdout, stderr = ssh.exec_command(command)
        output = stdout.read().decode('utf-8')
        error = stderr.read().decode('utf-8')

        ssh.close()

        if output:
            print("Users in database:")
            print(output)
        elif error:
            print(f"Error: {error}")
            print("\nTrying direct database access...")
        else:
            print("No users found or sqlite3 not available")

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_admin()
