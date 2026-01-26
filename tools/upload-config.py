#!/usr/bin/env python3
"""Upload hazinastore.config.json to remote server"""

import paramiko
from pathlib import Path

# SSH Configuration
SSH_HOST = "85.215.217.154"
SSH_USER = "administrator"
SSH_PASSWORD = "3WsXcFr$7YhNmKi*"

LOCAL_FILE = Path.home() / "AppData" / "Local" / "Temp" / "hazinastore.config.json"
REMOTE_FILE = "C:/stores/brand2boost/hazinastore.config.json"

def upload_and_restart():
    """Upload config file and restart backend"""
    try:
        # Create SSH/SFTP client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(SSH_HOST, username=SSH_USER, password=SSH_PASSWORD)

        # Upload file via SFTP
        sftp = ssh.open_sftp()
        sftp.put(str(LOCAL_FILE), REMOTE_FILE)
        sftp.close()

        print(f"Uploaded {LOCAL_FILE} to {REMOTE_FILE}")

        # Restart the website
        restart_cmd = "powershell -Command \"Import-Module WebAdministration; Stop-Website Brand2boostAPI; Start-Sleep -Seconds 2; Start-Website Brand2boostAPI\""
        stdin, stdout, stderr = ssh.exec_command(restart_cmd)
        output = stdout.read().decode('utf-8')
        error = stderr.read().decode('utf-8')

        ssh.close()

        print("Restarted Brand2boostAPI")

        if error:
            print(f"Restart error: {error}")
        else:
            print("SUCCESS: Backend should now accept requests from app.brand2boost.com")

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    upload_and_restart()
