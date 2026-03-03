#!/usr/bin/env python3
"""
FE Vending Machine API Client

Provides programmatic access to the FE Vending Machine for deploying
Databricks workspaces. Handles authentication automatically via cached
sessions or Chrome DevTools MCP.

Uses only Python standard library (no external dependencies).

Usage:
    python3 fe_vm_client.py refresh-cache
    python3 fe_vm_client.py deploy-serverless --name my-workspace --region us-east-1
    python3 fe_vm_client.py deploy-classic --name my-classic --region us-west-2
    python3 fe_vm_client.py status --run-id <run_id>
    python3 fe_vm_client.py wait --run-id <run_id>
    python3 fe_vm_client.py user-info
    python3 fe_vm_client.py quota
"""

import os
import sys
import json
import time
import random
import string
import argparse
import ssl
import urllib.request
import urllib.error
import urllib.parse
from pathlib import Path
from typing import Optional, Dict, List, Any

# Handle imports - we might be run directly or as module
SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPT_DIR))

from environment_manager import (
    get_session,
    save_session,
    update_environments_from_api,
    list_environments,
    find_workspace,
    ensure_directories,
    FEVM_DIR,
)


# API Configuration
FEVM_BASE_URL = "https://vending-machine-main-2481552415672103.aws.databricksapps.com"
FEVM_COOKIE_NAME = "__Host-databricksapps"

# Template IDs
TEMPLATE_SERVERLESS = 3
TEMPLATE_CLASSIC = 4

# Deployment intents
INTENT_CUSTOMER_DEMO = "Customer Demo/Testing"
INTENT_EXPERIMENTING = "Experimenting and Learning"
INTENT_BUILDER = "Builder Resource and Internal Application"


class AuthenticationError(Exception):
    """Raised when authentication fails or is required."""
    pass


class HTTPError(Exception):
    """Raised when HTTP request fails."""
    def __init__(self, status_code: int, message: str):
        self.status_code = status_code
        super().__init__(f"HTTP {status_code}: {message}")


class FEVMClient:
    """Client for the FE Vending Machine API."""

    def __init__(self, session_cookie: Optional[str] = None):
        """
        Initialize the FEVM client.

        Args:
            session_cookie: Session cookie value. If not provided, reads from cache.
        """
        self.base_url = FEVM_BASE_URL
        self._cookie = None
        self._user_info = None

        # Create SSL context
        self._ssl_context = ssl.create_default_context()

        # Try to get session cookie
        if session_cookie:
            self._cookie = session_cookie
        else:
            cached = get_session()
            if cached and cached.get("cookie"):
                self._cookie = cached["cookie"]

    def _request(self, method: str, endpoint: str, data: Optional[Dict] = None) -> Dict[str, Any]:
        """Make an authenticated request using urllib."""
        url = f"{self.base_url}{endpoint}"

        # Prepare headers
        headers = {
            "Content-Type": "application/json",
            "Accept": "*/*",
            "User-Agent": "FEVM-Client/1.0",
        }

        if self._cookie:
            headers["Cookie"] = f"{FEVM_COOKIE_NAME}={self._cookie}"

        # Prepare request body
        body = None
        if data is not None:
            body = json.dumps(data).encode("utf-8")

        # Create request
        req = urllib.request.Request(
            url,
            data=body,
            headers=headers,
            method=method
        )

        try:
            with urllib.request.urlopen(req, context=self._ssl_context) as response:
                response_body = response.read().decode("utf-8")
                return json.loads(response_body) if response_body else {}

        except urllib.error.HTTPError as e:
            if e.code in [401, 403]:
                raise AuthenticationError(
                    "Session expired or invalid. Re-authentication required.\n"
                    "Run: python3 browser_auth.py authenticate"
                )
            # Try to get error body
            try:
                error_body = e.read().decode("utf-8")
            except Exception:
                error_body = str(e)
            raise HTTPError(e.code, error_body)

        except urllib.error.URLError as e:
            raise HTTPError(0, f"Connection error: {e.reason}")

    def is_authenticated(self) -> bool:
        """Check if we have valid authentication."""
        try:
            self.get_user_info()
            return True
        except (AuthenticationError, HTTPError):
            return False

    def get_user_info(self) -> Dict[str, Any]:
        """Get current user information."""
        if self._user_info is None:
            self._user_info = self._request("GET", "/api/user-info")
        return self._user_info

    def list_deployments(self) -> List[Dict[str, Any]]:
        """List all deployments."""
        result = self._request("GET", "/api/deployments")
        return result.get("deployments", [])

    def list_templates(self) -> List[Dict[str, Any]]:
        """List available templates."""
        result = self._request("GET", "/api/templates")
        return result.get("templates", [])

    def get_quota(self) -> Dict[str, Any]:
        """Get quota information."""
        return self._request("GET", "/api/quota/all")

    def _generate_name(self, prefix: str) -> str:
        """Generate a unique workspace name."""
        suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=6))
        return f"{prefix}-{suffix}"

    def _validate_workflow_url(self, environment: str, cloud_provider: str):
        """Validate workflow URL before deployment."""
        return self._request(
            "POST",
            "/api/validate_workflow_url",
            data={"environment": environment, "cloud_provider": cloud_provider}
        )

    def deploy_serverless(
        self,
        workspace_name: Optional[str] = None,
        region: str = "us-east-1",
        lifetime_days: int = 30,
        environment: str = "prod",
        intent: str = INTENT_CUSTOMER_DEMO
    ) -> Dict[str, Any]:
        """Deploy a Serverless workspace."""
        if workspace_name is None:
            workspace_name = self._generate_name("serverless")

        user_info = self.get_user_info()

        # Validate first
        self._validate_workflow_url(environment, "aws")

        payload = {
            "selected_template": "Serverless Deployment",
            "variables": {
                "aws_region": region,
                "resource_owner": user_info["email"],
                "workspace_deployment_name": workspace_name,
                "resource_prefix": workspace_name,
                "resource_lifetime": str(lifetime_days)
            },
            "environment": environment,
            "cloud_provider": "aws",
            "post_deploy_params": None,
            "deployment_metadata": {"intent": intent}
        }

        return self._request("POST", "/api/create_terraform", data=payload)

    def deploy_classic(
        self,
        workspace_name: Optional[str] = None,
        region: str = "us-east-1",
        lifetime_days: int = 30,
        environment: str = "prod",
        intent: str = INTENT_CUSTOMER_DEMO
    ) -> Dict[str, Any]:
        """Deploy a Classic workspace."""
        if workspace_name is None:
            workspace_name = self._generate_name("classic")

        user_info = self.get_user_info()

        # Validate first
        self._validate_workflow_url(environment, "aws")

        payload = {
            "selected_template": "Classic Deployment",
            "variables": {
                "aws_region": region,
                "resource_owner": user_info["email"],
                "workspace_deployment_name": workspace_name,
                "resource_prefix": workspace_name,
                "resource_lifetime": str(lifetime_days)
            },
            "environment": environment,
            "cloud_provider": "aws",
            "post_deploy_params": None,
            "deployment_metadata": {"intent": intent}
        }

        return self._request("POST", "/api/create_terraform", data=payload)

    def check_workflow_status(self, run_id: str) -> Dict[str, Any]:
        """Check deployment status."""
        return self._request(
            "POST",
            "/api/check_workflow_status",
            data={"run_id": run_id}
        )

    def wait_for_deployment(
        self,
        run_id: str,
        timeout_minutes: int = 30,
        poll_interval: int = 30
    ) -> Dict[str, Any]:
        """Wait for deployment to complete."""
        start_time = time.time()
        timeout_seconds = timeout_minutes * 60

        while time.time() - start_time < timeout_seconds:
            status = self.check_workflow_status(run_id)
            workflow_status = status.get("workflow_status", "").lower()

            if workflow_status == "completed":
                conclusion = status.get("workflow_conclusion", "").lower()
                if conclusion == "success":
                    # Refresh cache after successful deployment
                    try:
                        deployments = self.list_deployments()
                        update_environments_from_api(deployments)
                    except Exception:
                        pass
                    return status
                else:
                    raise RuntimeError(f"Deployment failed: {status}")

            if workflow_status in ["failure", "failed", "cancelled"]:
                raise RuntimeError(f"Deployment failed: {status}")

            print(f"Status: {workflow_status}, waiting {poll_interval}s...", file=sys.stderr)
            time.sleep(poll_interval)

        raise TimeoutError(f"Deployment did not complete within {timeout_minutes} minutes")

    def refresh_cache(self) -> List[Dict[str, Any]]:
        """Fetch deployments and update cache."""
        deployments = self.list_deployments()
        workspaces = update_environments_from_api(deployments)
        return workspaces


def require_auth() -> FEVMClient:
    """
    Get an authenticated client, or print auth instructions and exit.
    """
    session = get_session()

    if not session or not session.get("cookie"):
        print("ERROR: No valid session found.", file=sys.stderr)
        print("\nAuthentication required. Use Chrome DevTools MCP to authenticate:", file=sys.stderr)
        print("\n1. Navigate to FEVM:", file=sys.stderr)
        print(f'   mcp-cli call chrome-devtools/navigate_page \'{{"type": "url", "url": "{FEVM_BASE_URL}/"}}\'\n', file=sys.stderr)
        print("2. Complete SSO login if prompted\n", file=sys.stderr)
        print("3. List network requests and get cookie from request headers:", file=sys.stderr)
        print('   mcp-cli call chrome-devtools/list_network_requests \'{"resourceTypes": ["fetch"]}\'\n', file=sys.stderr)
        print('   mcp-cli call chrome-devtools/get_network_request \'{"reqid": <reqid>}\'\n', file=sys.stderr)
        print("4. Save the cookie (extract __Host-databricksapps value from Cookie header):", file=sys.stderr)
        print('   python3 browser_auth.py save-cookie "<cookie_value>"\n', file=sys.stderr)
        sys.exit(1)

    client = FEVMClient(session["cookie"])

    # Verify the session is still valid
    if not client.is_authenticated():
        print("ERROR: Session expired.", file=sys.stderr)
        print("\nRe-authentication required. Follow the steps above.", file=sys.stderr)
        sys.exit(1)

    return client


def main():
    parser = argparse.ArgumentParser(
        description="FE Vending Machine API Client",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # refresh-cache
    subparsers.add_parser("refresh-cache", help="Fetch deployments and update local cache")

    # deploy-serverless
    deploy_sl = subparsers.add_parser("deploy-serverless", help="Deploy a Serverless workspace")
    deploy_sl.add_argument("--name", help="Workspace name (auto-generated if not provided)")
    deploy_sl.add_argument("--region", default="us-east-1", help="AWS region")
    deploy_sl.add_argument("--lifetime", type=int, default=30, help="Days until deletion (1-30)")
    deploy_sl.add_argument("--wait", action="store_true", help="Wait for completion")
    deploy_sl.add_argument("--json", action="store_true", help="Output as JSON")

    # deploy-classic
    deploy_cl = subparsers.add_parser("deploy-classic", help="Deploy a Classic workspace")
    deploy_cl.add_argument("--name", help="Workspace name (auto-generated if not provided)")
    deploy_cl.add_argument("--region", default="us-east-1", help="AWS region")
    deploy_cl.add_argument("--lifetime", type=int, default=30, help="Days until deletion (1-30)")
    deploy_cl.add_argument("--wait", action="store_true", help="Wait for completion")
    deploy_cl.add_argument("--json", action="store_true", help="Output as JSON")

    # status
    status_parser = subparsers.add_parser("status", help="Check deployment status")
    status_parser.add_argument("--run-id", required=True, help="Run ID from deployment")
    status_parser.add_argument("--json", action="store_true", help="Output as JSON")

    # wait
    wait_parser = subparsers.add_parser("wait", help="Wait for deployment to complete")
    wait_parser.add_argument("--run-id", required=True, help="Run ID from deployment")
    wait_parser.add_argument("--timeout", type=int, default=30, help="Timeout in minutes")
    wait_parser.add_argument("--json", action="store_true", help="Output as JSON")

    # user-info
    ui_parser = subparsers.add_parser("user-info", help="Get current user info")
    ui_parser.add_argument("--json", action="store_true", help="Output as JSON")

    # quota
    quota_parser = subparsers.add_parser("quota", help="Get quota information")
    quota_parser.add_argument("--json", action="store_true", help="Output as JSON")

    # check-auth
    subparsers.add_parser("check-auth", help="Check if authenticated")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    ensure_directories()

    # Commands that don't require auth
    if args.command == "check-auth":
        session = get_session()
        if session and session.get("cookie"):
            client = FEVMClient(session["cookie"])
            if client.is_authenticated():
                user = client.get_user_info()
                print(json.dumps({
                    "authenticated": True,
                    "email": user.get("email"),
                    "role": user.get("role")
                }, indent=2))
                sys.exit(0)

        print(json.dumps({"authenticated": False}))
        sys.exit(1)

    # Commands that require auth
    client = require_auth()

    if args.command == "refresh-cache":
        workspaces = client.refresh_cache()
        active = [w for w in workspaces if w.get("state") == "Active"]
        print(f"Cache refreshed. Found {len(active)} active workspaces.")

        if active:
            print("\nActive workspaces:")
            for w in active:
                print(f"  - {w.get('workspace_name')}: {w.get('workspace_url')}")
                print(f"    Type: {w.get('workspace_type')}, Days remaining: {w.get('days_remaining', 0):.1f}")

    elif args.command == "deploy-serverless":
        result = client.deploy_serverless(
            workspace_name=args.name,
            region=args.region,
            lifetime_days=args.lifetime
        )

        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(f"Deployment started!")
            print(f"  Run ID: {result.get('run_id')}")
            print(f"  Status: {result.get('workflow_status')}")
            print(f"\nMonitor with: python3 fe_vm_client.py status --run-id {result.get('run_id')}")

        if args.wait and result.get("status") == "success":
            print("\nWaiting for deployment to complete...")
            try:
                final = client.wait_for_deployment(result["run_id"])
                if args.json:
                    print(json.dumps(final, indent=2))
                else:
                    print(f"\nDeployment complete!")
                    print(f"  Status: {final.get('workflow_conclusion')}")

                    # Show workspace info
                    workspaces = list_environments()
                    for w in workspaces:
                        if result.get("run_id") in str(w):
                            print(f"  URL: {w.get('workspace_url')}")
            except (RuntimeError, TimeoutError) as e:
                print(f"\nDeployment failed: {e}", file=sys.stderr)
                sys.exit(1)

    elif args.command == "deploy-classic":
        result = client.deploy_classic(
            workspace_name=args.name,
            region=args.region,
            lifetime_days=args.lifetime
        )

        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(f"Deployment started!")
            print(f"  Run ID: {result.get('run_id')}")
            print(f"  Status: {result.get('workflow_status')}")
            print(f"\nMonitor with: python3 fe_vm_client.py status --run-id {result.get('run_id')}")

        if args.wait and result.get("status") == "success":
            print("\nWaiting for deployment to complete...")
            try:
                final = client.wait_for_deployment(result["run_id"])
                if args.json:
                    print(json.dumps(final, indent=2))
                else:
                    print(f"\nDeployment complete!")
                    print(f"  Status: {final.get('workflow_conclusion')}")
            except (RuntimeError, TimeoutError) as e:
                print(f"\nDeployment failed: {e}", file=sys.stderr)
                sys.exit(1)

    elif args.command == "status":
        status = client.check_workflow_status(args.run_id)

        if args.json:
            print(json.dumps(status, indent=2))
        else:
            print(f"Run ID: {args.run_id}")
            print(f"  Status: {status.get('workflow_status')}")
            print(f"  Conclusion: {status.get('workflow_conclusion', 'N/A')}")
            print(f"  Message: {status.get('message', 'N/A')}")

            if status.get("html_url"):
                print(f"  GitHub URL: {status.get('html_url')}")

    elif args.command == "wait":
        print(f"Waiting for deployment {args.run_id}...")
        try:
            result = client.wait_for_deployment(args.run_id, timeout_minutes=args.timeout)

            if args.json:
                print(json.dumps(result, indent=2))
            else:
                print(f"\nDeployment complete!")
                print(f"  Status: {result.get('workflow_conclusion')}")
        except (RuntimeError, TimeoutError) as e:
            print(f"\nFailed: {e}", file=sys.stderr)
            sys.exit(1)

    elif args.command == "user-info":
        info = client.get_user_info()

        if args.json:
            print(json.dumps(info, indent=2))
        else:
            print(f"User: {info.get('email')}")
            print(f"Role: {info.get('role')}")
            print(f"Permissions: {', '.join(info.get('permissions', []))}")

    elif args.command == "quota":
        quota = client.get_quota()

        if args.json:
            print(json.dumps(quota, indent=2))
        else:
            print(f"Quota for: {quota.get('user_email')}")
            print()
            for t in quota.get("templates", []):
                if t.get("can_deploy"):
                    user_q = t.get("user_quota", {})
                    global_l = t.get("global_limit", {})
                    print(f"  {t.get('template_name')}:")
                    print(f"    User: {user_q.get('current_count', 0)}/{user_q.get('quota_limit', 0)}")
                    print(f"    Global: {global_l.get('global_current_count', 0)}/{global_l.get('global_limit', 0)}")


if __name__ == "__main__":
    main()
