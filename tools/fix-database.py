#!/usr/bin/env python3
"""Backup and reset the identity database"""

import paramiko
from datetime import datetime

# SSH Configuration
SSH_HOST = "85.215.217.154"
SSH_USER = "administrator"
SSH_PASSWORD = "3WsXcFr$7YhNmKi*"

def fix_database():
    """Backup existing database and let migrations recreate it"""
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(SSH_HOST, username=SSH_USER, password=SSH_PASSWORD)

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        # Commands to execute
        commands = [
            # Stop website
            "powershell -Command \"Import-Module WebAdministration; Stop-Website Brand2boostAPI\"",

            # Backup database
            f"copy C:\\stores\\brand2boost\\identity.db C:\\stores\\brand2boost\\identity.db.backup_{timestamp}",

            # Delete current database
            "del C:\\stores\\brand2boost\\identity.db",

            # Delete -wal and -shm files if they exist
            "del C:\\stores\\brand2boost\\identity.db-wal 2>nul",
            "del C:\\stores\\brand2boost\\identity.db-shm 2>nul",

            # Start website (migrations will auto-apply on startup)
            "powershell -Command \"Import-Module WebAdministration; Start-Website Brand2boostAPI; Start-Sleep -Seconds 5\"",
        ]

        for cmd in commands:
            print(f"Executing: {cmd}")
            stdin, stdout, stderr = ssh.exec_command(cmd)
            output = stdout.read().decode('utf-8', errors='ignore')
            error = stderr.read().decode('utf-8', errors='ignore')

            if output:
                print(f"  Output: {output.strip()}")
            if error and "cannot find" not in error.lower():
                print(f"  Error: {error.strip()}")

        ssh.close()

        print("\nDATABASE RESET COMPLETE")
        print(f"Old database backed up as identity.db.backup_{timestamp}")
        print("New database will be created automatically with correct schema")

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    fix_database()
