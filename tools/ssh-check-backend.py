#!/usr/bin/env python3
"""SSH utility to check and manage Brand2boost backend"""

import paramiko
import sys
from pathlib import Path

# SSH Configuration
SSH_HOST = "85.215.217.154"
SSH_USER = "administrator"
SSH_KEY_PATH = Path.home() / ".ssh" / "id_ed25519"

def execute_ssh_command(command):
    """Execute a command via SSH and return the output"""
    try:
        # Create SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        # Connect using password
        ssh.connect(SSH_HOST, username=SSH_USER, password="3WsXcFr$7YhNmKi*")

        # Execute command
        stdin, stdout, stderr = ssh.exec_command(command)

        # Get output
        output = stdout.read().decode('utf-8')
        error = stderr.read().decode('utf-8')

        # Close connection
        ssh.close()

        return output, error
    except Exception as e:
        return None, str(e)

def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "dir C:\\stores\\brand2boost"

    output, error = execute_ssh_command(command)

    if output:
        print(output)
    if error:
        print(f"Error: {error}", file=sys.stderr)

if __name__ == "__main__":
    main()
