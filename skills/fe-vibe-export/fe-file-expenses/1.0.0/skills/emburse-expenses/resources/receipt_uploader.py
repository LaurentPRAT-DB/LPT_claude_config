#!/usr/bin/env python3
"""
Receipt Uploader - Batch upload receipts to Emburse ChromeRiver eWallet

Uses Chrome DevTools MCP to upload receipts via the Receipt Gallery UI,
which properly handles the upload flow including authentication.

Prerequisites:
1. Chrome browser open with Emburse logged in (https://app.ca1.chromeriver.com)
2. Chrome DevTools MCP server running

Usage:
    python3 receipt_uploader.py list ~/Downloads              # List receipt files
    python3 receipt_uploader.py upload ~/Downloads/*.pdf      # Upload all PDFs
    python3 receipt_uploader.py upload receipt1.pdf receipt2.jpg  # Upload specific files
    python3 receipt_uploader.py batch ~/Downloads             # Upload all receipts in directory
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Supported receipt file types
SUPPORTED_EXTENSIONS = {'.pdf', '.jpg', '.jpeg', '.png', '.tiff', '.tif', '.heic', '.ofd'}

# Size limits (in bytes)
MIN_FILE_SIZE = 50 * 1024  # 50 KB
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB


def get_mcp_cli_cmd() -> List[str]:
    """Get the mcp-cli command, handling aliases."""
    import shutil
    # Try finding mcp-cli directly
    mcp_cli = shutil.which("mcp-cli")
    if mcp_cli:
        return [mcp_cli]

    # Check common locations for the Claude CLI with --mcp-cli flag
    claude_locations = [
        os.path.expanduser("~/.local/share/claude/versions/2.1.12"),
        os.path.expanduser("~/.local/bin/claude"),
        "/usr/local/bin/claude",
    ]
    for loc in claude_locations:
        if os.path.exists(loc):
            return [loc, "--mcp-cli"]

    # Fallback - try using bash to resolve alias
    return ["bash", "-ic", "mcp-cli"]


def run_mcp_command(server_tool: str, params: Dict) -> Tuple[bool, Dict]:
    """Run an MCP command via mcp-cli and return the result."""
    mcp_base = get_mcp_cli_cmd()
    cmd = mcp_base + ["call", server_tool, json.dumps(params)]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if result.returncode != 0:
            return False, {"error": result.stderr or "MCP command failed"}

        stdout = result.stdout

        # mcp-cli returns JSON with nested content structure:
        # { "content": [{ "type": "text", "text": "# response\n```json\n{...}\n```" }] }
        try:
            outer = json.loads(stdout)
            if isinstance(outer, dict) and "content" in outer:
                for item in outer.get("content", []):
                    if item.get("type") == "text":
                        text = item.get("text", "")
                        # Extract JSON from code block in text
                        json_match = re.search(r'```json\s*\n(.*?)\n```', text, re.DOTALL)
                        if json_match:
                            try:
                                return True, json.loads(json_match.group(1))
                            except json.JSONDecodeError:
                                pass
                        # Return the raw text if no JSON found
                        return True, {"text": text}
                # No JSON found in content, return the outer structure
                return True, outer
        except json.JSONDecodeError:
            pass

        # Fallback: try direct markdown parsing
        json_match = re.search(r'```json\s*\n(.*?)\n```', stdout, re.DOTALL)
        if json_match:
            try:
                return True, json.loads(json_match.group(1))
            except json.JSONDecodeError:
                pass

        # Return raw output for non-JSON responses
        return True, {"raw_output": stdout}
    except subprocess.TimeoutExpired:
        return False, {"error": "MCP command timed out"}
    except Exception as e:
        return False, {"error": str(e)}


def navigate_to_receipt_gallery() -> bool:
    """Navigate to the Emburse eWallet Receipt Gallery."""
    # Navigate to eWallet
    success, result = run_mcp_command("chrome-devtools/navigate_page",
                                       {"url": "https://app.ca1.chromeriver.com/index#ewallet"})
    if not success:
        print(f"Failed to navigate: {result.get('error')}", file=sys.stderr)
        return False

    time.sleep(2)  # Wait for page to load

    # Take snapshot to find Receipt Gallery button
    success, result = run_mcp_command("chrome-devtools/take_snapshot", {})
    if not success:
        return False

    # Find and click Receipt Gallery button
    text = result.get("text", "") or result.get("raw_output", "")

    # Look for Receipt Gallery button UID
    gallery_match = re.search(r'uid=(\d+_\d+)\s+button\s+"Receipt Gallery"', text)
    if not gallery_match:
        print("Could not find Receipt Gallery button", file=sys.stderr)
        return False

    gallery_uid = gallery_match.group(1)
    success, _ = run_mcp_command("chrome-devtools/click", {"uid": gallery_uid})
    if not success:
        return False

    time.sleep(1)  # Wait for gallery to open
    return True


def find_upload_button() -> Optional[str]:
    """Find the Upload button UID in the current page."""
    success, result = run_mcp_command("chrome-devtools/take_snapshot", {})
    if not success:
        return None

    text = result.get("text", "") or result.get("raw_output", "")

    # Look for Upload button UID
    upload_match = re.search(r'uid=(\d+_\d+)\s+button\s+"Upload"', text)
    if upload_match:
        return upload_match.group(1)
    return None


def upload_receipt_via_ui(file_path: str) -> Dict:
    """
    Upload a receipt file via the Receipt Gallery UI.

    Uses Chrome DevTools upload_file to interact with the file chooser.
    """
    # Find the Upload button
    upload_uid = find_upload_button()
    if not upload_uid:
        return {"success": False, "error": "Could not find Upload button", "file": file_path}

    # Use upload_file with the Upload button UID
    success, result = run_mcp_command("chrome-devtools/upload_file",
                                       {"uid": upload_uid, "filePath": file_path})

    if success:
        # Wait for upload to process
        time.sleep(3)
        return {"success": True, "file": os.path.basename(file_path)}
    else:
        return {"success": False, "error": result.get("error", "Upload failed"), "file": file_path}


def find_receipt_files(directory: str) -> List[str]:
    """Find all receipt files in a directory."""
    receipts = []
    dir_path = Path(directory).expanduser()

    if not dir_path.exists():
        print(f"Error: Directory not found: {directory}", file=sys.stderr)
        return []

    for ext in SUPPORTED_EXTENSIONS:
        receipts.extend(dir_path.glob(f"*{ext}"))
        receipts.extend(dir_path.glob(f"*{ext.upper()}"))

    # Filter by size
    valid_receipts = []
    for f in receipts:
        size = f.stat().st_size
        if MIN_FILE_SIZE <= size <= MAX_FILE_SIZE:
            valid_receipts.append(str(f))
        else:
            print(f"Skipping {f.name}: size {size} bytes outside valid range ({MIN_FILE_SIZE}-{MAX_FILE_SIZE})", file=sys.stderr)

    return sorted(valid_receipts)


def list_receipts(directory: str) -> None:
    """List all receipt files in a directory."""
    receipts = find_receipt_files(directory)

    if not receipts:
        print(f"No receipt files found in {directory}")
        print(f"Supported formats: {', '.join(sorted(SUPPORTED_EXTENSIONS))}")
        return

    print(f"Found {len(receipts)} receipt file(s) in {directory}:\n")
    for i, receipt in enumerate(receipts, 1):
        path = Path(receipt)
        size_kb = path.stat().st_size / 1024
        print(f"  {i}. {path.name} ({size_kb:.1f} KB)")


def upload_receipts(files: List[str], dry_run: bool = False) -> Dict:
    """Upload multiple receipt files via Receipt Gallery UI."""
    if not files:
        return {"error": "No files specified"}

    # Expand any glob patterns and validate files
    expanded_files = []
    for f in files:
        path = Path(f).expanduser()
        if path.is_dir():
            expanded_files.extend(find_receipt_files(str(path)))
        elif path.exists():
            expanded_files.append(str(path))
        else:
            print(f"Warning: File not found: {f}", file=sys.stderr)

    if not expanded_files:
        return {"error": "No valid files to upload"}

    if dry_run:
        print(f"Would upload {len(expanded_files)} file(s):")
        for f in expanded_files:
            print(f"  - {Path(f).name}")
        return {"dry_run": True, "files": expanded_files}

    # Navigate to Receipt Gallery
    print("Navigating to Receipt Gallery...")
    if not navigate_to_receipt_gallery():
        return {"error": "Failed to navigate to Receipt Gallery. Make sure you're logged into Emburse in Chrome."}

    print(f"Uploading {len(expanded_files)} file(s) to eWallet...\n")

    results = {"successful": [], "failed": []}

    for i, file_path in enumerate(expanded_files, 1):
        filename = Path(file_path).name
        print(f"[{i}/{len(expanded_files)}] Uploading {filename}...", end=" ", flush=True)

        result = upload_receipt_via_ui(file_path)

        if result.get("success"):
            print("OK")
            results["successful"].append({"file": filename})
        else:
            print(f"FAILED ({result.get('error', 'Unknown error')})")
            results["failed"].append({"file": filename, "error": result.get("error")})

        # Small delay between uploads
        if i < len(expanded_files):
            time.sleep(1)

    print(f"\nUpload complete: {len(results['successful'])} succeeded, {len(results['failed'])} failed")

    return results


def main():
    parser = argparse.ArgumentParser(
        description="Batch upload receipts to Emburse ChromeRiver eWallet via Chrome DevTools",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # List receipt files in Downloads
    python3 receipt_uploader.py list ~/Downloads

    # Upload all PDFs in Downloads
    python3 receipt_uploader.py upload ~/Downloads/*.pdf

    # Upload specific files
    python3 receipt_uploader.py upload receipt1.pdf receipt2.jpg

    # Batch upload all receipts in a directory
    python3 receipt_uploader.py batch ~/Downloads

    # Dry run to see what would be uploaded
    python3 receipt_uploader.py upload --dry-run ~/Downloads/*.pdf

Prerequisites:
    1. Chrome browser open and logged into Emburse at https://app.ca1.chromeriver.com
    2. Chrome DevTools MCP server running and connected to Claude Code
"""
    )

    subparsers = parser.add_subparsers(dest="command", help="Command to run")

    # List command
    list_parser = subparsers.add_parser("list", help="List receipt files in a directory")
    list_parser.add_argument("directory", help="Directory to scan for receipts")

    # Upload command
    upload_parser = subparsers.add_parser("upload", help="Upload receipt files")
    upload_parser.add_argument("files", nargs="+", help="Files to upload (or directory)")
    upload_parser.add_argument("--dry-run", action="store_true", help="Show what would be uploaded without uploading")

    # Batch command
    batch_parser = subparsers.add_parser("batch", help="Upload all receipts in a directory")
    batch_parser.add_argument("directory", help="Directory containing receipts")
    batch_parser.add_argument("--dry-run", action="store_true", help="Show what would be uploaded without uploading")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    if args.command == "list":
        list_receipts(args.directory)

    elif args.command == "upload":
        result = upload_receipts(args.files, dry_run=args.dry_run)
        if "error" in result:
            print(f"Error: {result['error']}", file=sys.stderr)
            sys.exit(1)

    elif args.command == "batch":
        receipts = find_receipt_files(args.directory)
        if not receipts:
            print(f"No receipt files found in {args.directory}")
            sys.exit(1)
        result = upload_receipts(receipts, dry_run=args.dry_run)
        if "error" in result:
            print(f"Error: {result['error']}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
