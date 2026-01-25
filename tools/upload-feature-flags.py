#!/usr/bin/env python3
"""Upload feature flags configuration to production server"""

import paramiko
import json

SSH_HOST = "85.215.217.154"
SSH_USER = "administrator"
SSH_PASSWORD = "3WsXcFr$7YhNmKi*"

# Feature flags configuration
FEATURE_FLAGS = {
    "FeatureFlags": {
        "EnableGuidanceCards": True,
        "EnableSystemStatusLines": True,
        "EnableArtifactCards": True,
        "EnableGeneratedItemsList": True,
        "EnableDashboardPanels": True,
        "EnableCommandPalette": True,
        "EnableLogsPanel": True,
        "EnableComponentsPanel": True,
        "UseSingleLLMOrchestration": True
    }
}

def upload_feature_flags():
    """Upload feature flags config and restart backend"""
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(SSH_HOST, username=SSH_USER, password=SSH_PASSWORD)

        print("Connected to server")
        print()

        # Create feature flags JSON
        config_json = json.dumps(FEATURE_FLAGS, indent=2)

        # Write to temp file on local machine
        temp_file = "C:\\Users\\HP\\AppData\\Local\\Temp\\feature-flags.json"
        with open(temp_file, 'w') as f:
            f.write(config_json)

        print("Created feature-flags.json:")
        print(config_json)
        print()

        # Upload via SFTP
        print("Uploading to server...")
        sftp = ssh.open_sftp()

        # Upload to backend directory
        remote_path = "C:/stores/brand2boost/backend/Configuration/feature-flags.json"
        sftp.put(temp_file, remote_path)
        sftp.close()

        print(f"Uploaded to: {remote_path}")
        print()

        # Restart backend to reload configuration
        print("Restarting backend...")
        commands = [
            'powershell -Command "Import-Module WebAdministration; Restart-WebAppPool -Name (Get-Website \'Brand2boostAPI\').applicationPool"'
        ]

        for cmd in commands:
            stdin, stdout, stderr = ssh.exec_command(cmd)
            output = stdout.read().decode('utf-8')
            error = stderr.read().decode('utf-8')

            if output:
                print(f"  Output: {output.strip()}")
            if error:
                print(f"  Error: {error.strip()}")

        print()
        print("Backend restarted successfully!")
        print()
        print("Verifying feature flags...")

        # Wait a moment for restart
        import time
        time.sleep(3)

        # Check API
        import requests
        response = requests.get("https://api.brand2boost.com/api/featureflags")
        if response.status_code == 200:
            flags = response.json()
            print(json.dumps(flags, indent=2))

            # Check if all flags are enabled
            all_enabled = all(flags.values())
            if all_enabled:
                print()
                print("[SUCCESS] All feature flags are enabled!")
            else:
                print()
                print("[WARNING] Some flags are still disabled:")
                for flag, enabled in flags.items():
                    if not enabled:
                        print(f"  - {flag}: {enabled}")
        else:
            print(f"Failed to verify: HTTP {response.status_code}")

        ssh.close()

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    upload_feature_flags()
