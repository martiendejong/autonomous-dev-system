#!/usr/bin/env python3
"""Enable all feature flags on brand2boost production"""

import requests
import json

API_BASE = "https://api.brand2boost.com"

# Feature flags to enable
FLAGS = {
    "EnableArtifactCards": True,
    "EnableCommandPalette": True,
    "EnableComponentsPanel": True,
    "EnableDashboardPanels": True,
    "EnableGeneratedItemsList": True,
    "EnableGuidanceCards": True,
    "EnableLogsPanel": True,
    "EnableSystemStatusLines": True,
    "UseSingleLLMOrchestration": True
}

def enable_flags():
    """Enable all feature flags"""
    print("Enabling feature flags on production...")
    print(f"API: {API_BASE}")
    print()

    # Update each flag
    for flag_name, flag_value in FLAGS.items():
        url = f"{API_BASE}/api/featureflags/{flag_name}"

        try:
            response = requests.put(
                url,
                json=flag_value,
                headers={"Content-Type": "application/json"}
            )

            if response.status_code == 200:
                print(f"[OK] {flag_name}: {flag_value}")
            else:
                print(f"[FAIL] {flag_name}: HTTP {response.status_code}")
                print(f"  Response: {response.text}")
        except Exception as e:
            print(f"[ERROR] {flag_name}: {e}")

    print()
    print("Verifying feature flags...")

    # Get current flags
    try:
        response = requests.get(f"{API_BASE}/api/featureflags")
        if response.status_code == 200:
            flags = response.json()
            print(json.dumps(flags, indent=2))
        else:
            print(f"Failed to get flags: HTTP {response.status_code}")
    except Exception as e:
        print(f"Error getting flags: {e}")

if __name__ == "__main__":
    enable_flags()
