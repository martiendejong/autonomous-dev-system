#!/usr/bin/env python3
"""
ClickUp Integration Helper for Feature Idea Generator

Creates tasks in ClickUp backlog from top features.
"""

import os
import sys
import json
import requests
from pathlib import Path

# ClickUp API configuration
CLICKUP_API_KEY = os.environ.get("CLICKUP_API_KEY")
CLICKUP_API_URL = "https://api.clickup.com/api/v2"

def get_project_clickup_id(project_name):
    """
    Get ClickUp list ID for project from PROJECT_MASTER_MAP.md

    Args:
        project_name: Name of the project

    Returns:
        ClickUp list ID or None if not found
    """
    master_map = Path("C:/scripts/_machine/PROJECT_MASTER_MAP.md")

    if not master_map.exists():
        print(f"ERROR: PROJECT_MASTER_MAP.md not found at {master_map}")
        return None

    content = master_map.read_text(encoding='utf-8')

    # Look for project entry
    for line in content.split('\n'):
        if project_name.lower() in line.lower():
            # Extract ClickUp ID
            if 'clickup:' in line.lower():
                parts = line.split('clickup:')
                if len(parts) > 1:
                    clickup_id = parts[1].strip().split()[0].strip('`')
                    return clickup_id

    return None

def create_feature_task(list_id, feature_data, ideation_path):
    """
    Create a ClickUp task for a feature

    Args:
        list_id: ClickUp list ID
        feature_data: Dictionary with feature details
        ideation_path: Path to ideation documents

    Returns:
        Created task data or None if failed
    """
    if not CLICKUP_API_KEY:
        print("ERROR: CLICKUP_API_KEY not set in environment")
        return None

    headers = {
        "Authorization": CLICKUP_API_KEY,
        "Content-Type": "application/json"
    }

    # Build task description
    description = f"""## Value Proposition
{feature_data.get('value_proposition', 'N/A')}

## User Story
**As a** {feature_data.get('user_type', 'user')}
**I want** {feature_data.get('capability', 'N/A')}
**So that** {feature_data.get('benefit', 'N/A')}

## Unique Value
{feature_data.get('unique_value', 'N/A')}

## Success Metrics
{feature_data.get('success_metrics', 'N/A')}

## Implementation Notes
{feature_data.get('implementation_notes', 'N/A')}

## Ideation Process

This feature was generated through systematic expert analysis:

1. **Expert Panel:** 100+ domain experts analyzed product
2. **Core Value:** Identified transformative value proposition
3. **Ideation:** Generated 100 feature ideas
4. **Refinement:** Expert panel refined to billion-dollar features
5. **Prioritization:** Selected as Top 5 by value-to-effort ratio

**Full Analysis:** {ideation_path}

**ROI Score:** {feature_data.get('roi', 'N/A')}
**Value Score:** {feature_data.get('value_score', 'N/A')}/100
**Effort Score:** {feature_data.get('effort_score', 'N/A')}/100

## References
See: {ideation_path}/top-5-features.md
"""

    # Build task payload
    task_data = {
        "name": f"[FEATURE] {feature_data.get('name', 'Untitled Feature')}",
        "description": description,
        "priority": 2,  # High priority
        "tags": ["feature", "high-impact", "innovation", "value-creation"]
    }

    # Create task
    url = f"{CLICKUP_API_URL}/list/{list_id}/task"

    try:
        response = requests.post(url, headers=headers, json=task_data)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"ERROR creating task: {e}")
        if hasattr(e.response, 'text'):
            print(f"Response: {e.response.text}")
        return None

def add_features_to_clickup(project_name, features_file):
    """
    Add top features from ideation to ClickUp backlog

    Args:
        project_name: Name of the project
        features_file: Path to top-5-features.md

    Returns:
        List of created task URLs
    """
    # Get ClickUp list ID
    list_id = get_project_clickup_id(project_name)

    if not list_id:
        print(f"ERROR: Could not find ClickUp list ID for project '{project_name}'")
        print("Check PROJECT_MASTER_MAP.md for correct project name")
        return []

    print(f"Found ClickUp list ID: {list_id}")

    # Read features file
    features_path = Path(features_file)
    if not features_path.exists():
        print(f"ERROR: Features file not found: {features_file}")
        return []

    # Parse features (simplified - assumes structured format)
    # In real implementation, would parse markdown more robustly
    content = features_path.read_text(encoding='utf-8')

    # Extract ideation path
    ideation_path = features_path.parent

    # For now, return empty list - actual parsing would extract feature data
    # This is a helper script template - full implementation would parse markdown
    print("NOTE: Feature parsing not implemented in this template")
    print("Manually create tasks or extend this script with markdown parsing")

    return []

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python clickup-integration.py <project_name> <features_file>")
        print("Example: python clickup-integration.py client-manager C:/scripts/_ideation/client-manager/top-5-features.md")
        sys.exit(1)

    project_name = sys.argv[1]
    features_file = sys.argv[2]

    task_urls = add_features_to_clickup(project_name, features_file)

    if task_urls:
        print("\n✅ Created tasks:")
        for url in task_urls:
            print(f"  - {url}")
    else:
        print("\n❌ No tasks created")
