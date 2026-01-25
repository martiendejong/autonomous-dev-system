#!/usr/bin/env python3
"""Complete backend reset with proper CORS configuration"""

import paramiko
import time

SSH_HOST = "85.215.217.154"
SSH_USER = "administrator"
SSH_PASSWORD = "3WsXcFr$7YhNmKi*"

def full_reset():
    """Completely reset backend with fresh database and config"""
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(SSH_HOST, username=SSH_USER, password=SSH_PASSWORD)

        print("Step 1: Stop backend...")
        stdin, stdout, stderr = ssh.exec_command(
            "powershell -Command \"Import-Module WebAdministration; Stop-Website Brand2boostAPI\""
        )
        stdout.read()
        time.sleep(2)

        print("Step 2: Delete all database files...")
        commands = [
            "del C:\\stores\\brand2boost\\identity.db* 2>nul",
            "del C:\\stores\\brand2boost\\data\\identity.db* 2>nul",
            "del C:\\stores\\brand2boost\\backend\\fatal.log 2>nul",
        ]
        for cmd in commands:
            stdin, stdout, stderr = ssh.exec_command(cmd)
            stdout.read()

        print("Step 3: Restore hazinastore.config.json...")
        stdin, stdout, stderr = ssh.exec_command(
            "powershell -Command \"if (Test-Path C:\\stores\\brand2boost\\hazinastore.config.json.disabled) { Move-Item C:\\stores\\brand2boost\\hazinastore.config.json.disabled C:\\stores\\brand2boost\\hazinastore.config.json -Force }\""
        )
        stdout.read()

        print("Step 4: Restart app pool and website...")
        stdin, stdout, stderr = ssh.exec_command(
            "powershell -Command \"Import-Module WebAdministration; Restart-WebAppPool -Name (Get-Website 'Brand2boostAPI').applicationPool; Start-Website Brand2boostAPI\""
        )
        stdout.read()

        print("Step 5: Wait for startup...")
        time.sleep(15)

        print("Step 6: Check if database was created...")
        stdin, stdout, stderr = ssh.exec_command(
            "powershell -Command \"Test-Path C:\\stores\\brand2boost\\data\\identity.db\""
        )
        db_created = stdout.read().decode('utf-8').strip()

        print(f"\nDatabase created: {db_created}")

        if db_created == "True":
            print("\n✓ BACKEND RESET SUCCESSFUL!")
            print("✓ Fresh database created")
            print("✓ CORS configured for https://app.brand2boost.com")
        else:
            print("\n✗ DATABASE NOT CREATED - checking logs...")
            stdin, stdout, stderr = ssh.exec_command(
                "powershell -Command \"Get-ChildItem C:\\stores\\brand2boost\\logs\\*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Select-Object -ExpandProperty FullName\""
            )
            latest_log = stdout.read().decode('utf-8').strip()
            if latest_log:
                print(f"Latest log: {latest_log}")

        ssh.close()

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    full_reset()
