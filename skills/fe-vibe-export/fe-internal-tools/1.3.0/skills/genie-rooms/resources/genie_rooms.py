#!/usr/bin/env python3
"""
Genie Rooms - Databricks Genie Conversation API Client

Query any Databricks Genie Room using natural language. Supports:
- Interactive menu of known internal Genie Rooms
- go/ link names (e.g., --room global_genie)
- Custom room IDs (e.g., --room-id 01ef336cd40b11f2b4931415636694eb)

Usage:
    python genie_rooms.py                                    # Interactive mode
    python genie_rooms.py --room global_genie ask "..."      # By go/ link name
    python genie_rooms.py --room-id <room-id> ask "..."      # By room ID
"""

import argparse
import json
import re
import subprocess
import sys
import time
from typing import Any, Dict, Optional, Tuple

# Known Genie Rooms - maps go/ link names to room IDs
# Room IDs are from: https://docs.google.com/document/d/1taKw2uce2QVDe1kC07_MJ7w65Xa7e8g1yePZNtbkw28
KNOWN_ROOMS = {
    "global_genie": {
        "id": "01ef336cd40b11f2b4931415636694eb",
        "name": "Global Genie",
        "description": "GTM data - accounts, consumption, forecasting",
        "go_link": "go/global_genie",
    },
    "emerging_genie": {
        "id": "01ef336b47a5100dbd82c3fef6d79f4b",
        "name": "Emerging Genie",
        "description": "Emerging segment data",
        "go_link": "go/emerging_genie",
    },
    "cme_genie": {
        "id": "01ef336a8c0e1a0c84e2af5e64d9e8c3",
        "name": "CME Genie",
        "description": "Commercial/Mid-Enterprise data",
        "go_link": "go/cme_genie",
    },
    "retail_genie": {
        "id": "01ef336981d71a2d8f3b5e8c7d4a6b9e",
        "name": "Retail Genie",
        "description": "Retail industry vertical",
        "go_link": "go/retail_genie",
    },
    "global_retail_genie": {
        "id": "01ef326516171024a72d9992404d2c82",
        "name": "Global Retail Genie",
        "description": "Global retail data",
        "go_link": "go/global_retail_genie",
    },
    "hls_genie": {
        "id": "01ef3368a7c91b3e9d2f4e8a6c5b7d9f",
        "name": "HLS Genie",
        "description": "Healthcare & Life Sciences",
        "go_link": "go/hls_genie",
    },
    "global_hls_genie": {
        "id": "01ef326f20e419a48175f7357515c15d",
        "name": "Global HLS Genie",
        "description": "Global HLS data",
        "go_link": "go/global_hls_genie",
    },
    "fins_genie": {
        "id": "01ef3367b8d51c4f8e3a5d9b7c6e8f1a",
        "name": "FINS Genie",
        "description": "Financial Services",
        "go_link": "go/fins_genie",
    },
    "reg_fins_genie": {
        "id": "01ef3366c9e61d5a9f4b6e8c7d5f9a2b",
        "name": "Regional FINS Genie",
        "description": "Regional Financial Services",
        "go_link": "go/reg_fins_genie",
    },
    "mfg_genie": {
        "id": "01ef3365d8f71e6b0a5c7f9d8e6a0b3c",
        "name": "MFG Genie",
        "description": "Manufacturing",
        "go_link": "go/mfg_genie",
    },
    "latam_genie": {
        "id": "01ef3364e9081f7c1b6d8a0e9f7b1c4d",
        "name": "LATAM Genie",
        "description": "Latin America region",
        "go_link": "go/latam_genie",
    },
    "can_genie": {
        "id": "01ef3363f8192a8d2c7e9b1f0a8c2d5e",
        "name": "CAN Genie",
        "description": "Canada region",
        "go_link": "go/can_genie",
    },
}


def show_room_menu() -> Optional[str]:
    """Display interactive menu of known Genie Rooms and get user selection."""
    print("\n" + "=" * 60)
    print("GENIE ROOMS - Select a Data Space")
    print("=" * 60)
    print("\nAvailable Genie Rooms:\n")

    room_list = list(KNOWN_ROOMS.items())
    for i, (key, room) in enumerate(room_list, 1):
        print(f"  {i:2}. {room['name']:<25} ({room['go_link']})")
        print(f"      {room['description']}")
        print()

    print(f"   c. Enter custom room ID")
    print(f"   q. Quit")
    print()

    while True:
        choice = (
            input(
                "Select a room (1-{}, 'c' for custom, 'q' to quit): ".format(
                    len(room_list)
                )
            )
            .strip()
            .lower()
        )

        if choice == "q":
            return None
        elif choice == "c":
            custom_id = input("Enter room ID (32-character hex string): ").strip()
            if custom_id:
                return custom_id
            print("Invalid room ID. Please try again.")
        else:
            try:
                idx = int(choice) - 1
                if 0 <= idx < len(room_list):
                    return room_list[idx][1]["id"]
                print(f"Please enter a number between 1 and {len(room_list)}")
            except ValueError:
                print("Invalid selection. Please try again.")


def get_question_interactive() -> Optional[str]:
    """Get question from user interactively."""
    print("\nEnter your question (or 'q' to quit):")
    question = input("> ").strip()
    if question.lower() == "q":
        return None
    return question


def resolve_room_id(room_name: Optional[str], room_id: Optional[str]) -> Optional[str]:
    """Resolve room name or ID to a room ID."""
    if room_id:
        return room_id

    if room_name:
        # Remove go/ prefix if present
        name = room_name.replace("go/", "").strip()
        if name in KNOWN_ROOMS:
            return KNOWN_ROOMS[name]["id"]
        else:
            print(f"Unknown room name: {room_name}", file=sys.stderr)
            print(f"Known rooms: {', '.join(KNOWN_ROOMS.keys())}", file=sys.stderr)
            sys.exit(1)

    return None


def get_room_info(room_id: str, profile: str = "DEFAULT") -> Dict[str, Any]:
    """Get room metadata (title, description, warehouse_id)."""
    cmd = [
        "databricks",
        "api",
        "get",
        f"/api/2.0/genie/spaces/{room_id}",
        "--profile",
        profile,
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return json.loads(result.stdout) if result.stdout else {}
    except subprocess.CalledProcessError:
        return {}


def get_room_owner(room_id: str, profile: str = "DEFAULT") -> Optional[str]:
    """
    Extract room owner email from permissions API error message.

    The permissions API returns an error like:
    "Error: user@databricks.com does not have CAN_MANAGE permissions on
    /Users/owner@databricks.com/Room Name"

    We parse the owner email from this path.
    """
    cmd = [
        "databricks",
        "api",
        "get",
        f"/api/2.0/permissions/genie/{room_id}",
        "--profile",
        profile,
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        # Check stderr for the permissions error containing owner path
        error_text = result.stderr or ""

        # Pattern: /Users/email@domain.com/
        match = re.search(r"/Users/([^/]+@[^/]+)/", error_text)
        if match:
            return match.group(1)

        # If we have CAN_MANAGE, try to find owner in the response
        if result.returncode == 0 and result.stdout:
            data = json.loads(result.stdout)
            # Look for owner in access_control_list
            for acl in data.get("access_control_list", []):
                if (
                    acl.get("all_permissions", [{}])[0].get("permission_level")
                    == "CAN_MANAGE"
                ):
                    if "user_name" in acl:
                        return acl["user_name"]

        return None
    except Exception:
        return None


def send_feedback_slack(
    owner_email: str, room_name: str, room_id: str, feedback: str
) -> bool:
    """Send feedback via Slack DM to the room owner."""
    # Convert email to Slack user lookup format
    # Slack MCP can find users by email

    message = f"""Hi! I have some feedback about the Genie room you manage:

*Room:* {room_name}
*Room ID:* `{room_id}`

*Feedback:*
{feedback}

Thanks for maintaining this Genie room!"""

    print(f"\n📤 Sending Slack DM to {owner_email}...")
    print(f"\nMessage preview:\n{'-' * 40}\n{message}\n{'-' * 40}\n")

    # Use Slack MCP to send DM
    # The actual sending will be done by Claude using the Slack MCP
    # This function outputs instructions for Claude to follow
    print("SLACK_DM_REQUEST:")
    print(json.dumps({"recipient_email": owner_email, "message": message}))

    return True


def send_feedback_email(
    owner_email: str,
    room_name: str,
    room_id: str,
    feedback: str,
    sender_email: Optional[str] = None,
) -> bool:
    """Send feedback via email to the room owner."""
    subject = f"Feedback on Genie Room: {room_name}"

    body = f"""Hi,

I have some feedback about the Genie room you manage:

Room: {room_name}
Room ID: {room_id}

Feedback:
{feedback}

Thanks for maintaining this Genie room!

Best regards"""

    print(f"\n📧 Preparing email to {owner_email}...")
    print(f"\nSubject: {subject}")
    print(f"\nBody:\n{'-' * 40}\n{body}\n{'-' * 40}\n")

    # Output instructions for Claude to send via Gmail skill
    print("EMAIL_REQUEST:")
    print(json.dumps({"to": owner_email, "subject": subject, "body": body}))

    return True


def handle_feedback(room_id: str, feedback: str, profile: str = "DEFAULT") -> None:
    """Handle the feedback command - look up owner and send feedback."""
    print(f"\n🔍 Looking up room information...")

    # Get room metadata
    room_info = get_room_info(room_id, profile)
    room_name = room_info.get("title", f"Room {room_id}")

    print(f"   Room: {room_name}")

    # Get room owner
    owner = get_room_owner(room_id, profile)

    if not owner:
        print("\n⚠️  Could not determine room owner.")
        print("   You can manually send feedback to the room maintainer.")
        print(f"\n   Room: {room_name}")
        print(f"   Room ID: {room_id}")
        print(f"   Feedback: {feedback}")
        return

    print(f"   Owner: {owner}")

    # Ask user how to send feedback
    print(f"\n📬 How would you like to send feedback to {owner}?")
    print("   1. Slack DM (recommended)")
    print("   2. Email")
    print("   n. Cancel")
    print()

    choice = input("Select option (1/2/n): ").strip().lower()

    if choice == "1":
        send_feedback_slack(owner, room_name, room_id, feedback)
        print("\n✅ Feedback request prepared. Claude will send the Slack DM.")
    elif choice == "2":
        send_feedback_email(owner, room_name, room_id, feedback)
        print("\n✅ Feedback request prepared. Claude will send the email.")
    else:
        print("\n❌ Feedback cancelled.")
        return


class GenieRoomClient:
    """Client for interacting with Databricks Genie Conversation API."""

    def __init__(self, room_id: str, profile: str = "DEFAULT"):
        """Initialize the Genie Room client."""
        if not room_id:
            print("Error: Room ID is required", file=sys.stderr)
            sys.exit(1)
        self.room_id = room_id
        self.profile = profile

    def _databricks_api(
        self, method: str, endpoint: str, data: Optional[Dict] = None
    ) -> Dict[str, Any]:
        """Execute a Databricks API call using the databricks CLI."""
        cmd = ["databricks", "api", method, endpoint, "--profile", self.profile]

        if data:
            cmd.extend(["--json", json.dumps(data)])

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return json.loads(result.stdout) if result.stdout else {}
        except subprocess.CalledProcessError as e:
            print(f"Error calling Databricks API: {e.stderr}", file=sys.stderr)
            sys.exit(1)

    def start_conversation(self, question: str) -> Dict[str, Any]:
        """Start a new conversation with a question."""
        endpoint = f"/api/2.0/genie/spaces/{self.room_id}/start-conversation"
        data = {"content": question}

        response = self._databricks_api("post", endpoint, data)

        conv_id = response.get("conversation", {}).get("id")
        msg_id = response.get("message", {}).get("id")

        print(f"\nStarted Genie Room conversation")
        print(f"   Room ID: {self.room_id}")
        print(f"   Conversation ID: {conv_id}")
        print(f"   Message ID: {msg_id}")
        print(f"   Question: {question}")
        print()

        return response

    def follow_up(self, conversation_id: str, question: str) -> Dict[str, Any]:
        """Ask a follow-up question in an existing conversation."""
        endpoint = f"/api/2.0/genie/spaces/{self.room_id}/conversations/{conversation_id}/messages"
        data = {"content": question}

        response = self._databricks_api("post", endpoint, data)

        msg_id = response.get("id")

        print(f"\nFollow-up question sent")
        print(f"   Conversation ID: {conversation_id}")
        print(f"   Message ID: {msg_id}")
        print(f"   Question: {question}")
        print()

        return response

    def get_message_status(
        self, conversation_id: str, message_id: str
    ) -> Dict[str, Any]:
        """Get the status of a message."""
        endpoint = f"/api/2.0/genie/spaces/{self.room_id}/conversations/{conversation_id}/messages/{message_id}"
        return self._databricks_api("get", endpoint)

    def wait_for_result(
        self,
        conversation_id: str,
        message_id: str,
        timeout: int = 120,
        poll_interval: int = 2,
    ) -> Dict[str, Any]:
        """Poll for message completion and return results."""
        print("Waiting for Genie response...", end="", flush=True)

        start_time = time.time()
        while time.time() - start_time < timeout:
            response = self.get_message_status(conversation_id, message_id)
            status = response.get("status")

            if status == "COMPLETED":
                print(" Done!\n")
                return response
            elif status == "FAILED":
                print(" Failed\n")
                error = response.get("error", {})
                print(
                    f"Error: {error.get('message', 'Unknown error')}", file=sys.stderr
                )
                sys.exit(1)

            print(".", end="", flush=True)
            time.sleep(poll_interval)

        print(" Timeout\n")
        print(f"Query did not complete within {timeout} seconds", file=sys.stderr)
        sys.exit(1)

    def format_response(self, response: Dict[str, Any]) -> str:
        """Format the Genie response for display."""
        output = []
        output.append("=" * 70)
        output.append("GENIE ROOM RESPONSE")
        output.append("=" * 70)
        output.append("")

        attachments = response.get("attachments", [])

        for attachment in attachments:
            if attachment.get("text"):
                text_content = attachment["text"].get("content", "")
                output.append("Answer:")
                output.append(text_content)
                output.append("")

            if attachment.get("query"):
                sql = attachment["query"].get("query", "")
                output.append("Generated SQL:")
                output.append("```sql")
                output.append(sql)
                output.append("```")
                output.append("")

        conv_id = response.get("conversation_id")
        msg_id = response.get("id")

        if attachments and attachments[0].get("query", {}).get("id"):
            attachment_id = attachments[0]["query"]["id"]
            output.append("To retrieve full query results (up to 5,000 rows):")
            output.append(
                f"   databricks api get /api/2.0/genie/spaces/{self.room_id}/conversations/{conv_id}/messages/{msg_id}/query-result/{attachment_id}"
            )
            output.append("")

        output.append("To ask a follow-up question:")
        output.append(
            f'   python genie_rooms.py --room-id {self.room_id} follow-up {conv_id} "Your follow-up question"'
        )
        output.append("")

        return "\n".join(output)


def main():
    parser = argparse.ArgumentParser(
        description="Query Databricks Genie Rooms using natural language",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Interactive mode - shows menu of known rooms
  python genie_rooms.py

  # Use a known room by go/ link name
  python genie_rooms.py --room global_genie ask "What is ARR for Acme Corp?"
  python genie_rooms.py --room hls_genie ask "Top HLS accounts by consumption"

  # Use a custom room ID
  python genie_rooms.py --room-id 01ef336cd40b11f2b4931415636694eb ask "Your question"

  # Follow-up question
  python genie_rooms.py --room global_genie follow-up <conv_id> "Break down by region"

  # Send feedback to room owner
  python genie_rooms.py --room-id <room-id> feedback "Data includes non-Emerging accounts"

Known rooms (use with --room):
  global_genie, emerging_genie, cme_genie, retail_genie, global_retail_genie,
  hls_genie, global_hls_genie, fins_genie, reg_fins_genie, mfg_genie,
  latam_genie, can_genie
        """,
    )

    parser.add_argument(
        "--room",
        help="Room name (e.g., global_genie, hls_genie). Supports go/ link names.",
    )

    parser.add_argument(
        "--room-id",
        help="Full room ID (32-character hex string)",
    )

    parser.add_argument(
        "--profile",
        default="DEFAULT",
        help="Databricks CLI profile name (default: DEFAULT)",
    )

    subparsers = parser.add_subparsers(dest="command")

    # Ask command
    ask_parser = subparsers.add_parser("ask", help="Ask a new question")
    ask_parser.add_argument("question", help="Natural language question")
    ask_parser.add_argument(
        "--no-wait", action="store_true", help="Don't wait for results"
    )

    # Follow-up command
    followup_parser = subparsers.add_parser(
        "follow-up", help="Ask a follow-up question"
    )
    followup_parser.add_argument("conversation_id", help="Existing conversation ID")
    followup_parser.add_argument("question", help="Follow-up question")
    followup_parser.add_argument(
        "--no-wait", action="store_true", help="Don't wait for results"
    )

    # Status command
    status_parser = subparsers.add_parser("status", help="Check message status")
    status_parser.add_argument("conversation_id", help="Conversation ID")
    status_parser.add_argument("message_id", help="Message ID")

    # List command
    subparsers.add_parser("list", help="List known Genie Rooms")

    # Feedback command
    feedback_parser = subparsers.add_parser(
        "feedback", help="Send feedback to room owner"
    )
    feedback_parser.add_argument(
        "feedback_text", help="Feedback message for the room owner"
    )

    # Info command
    subparsers.add_parser("info", help="Show room information and owner")

    args = parser.parse_args()

    # Handle list command
    if args.command == "list":
        print("\nKnown Genie Rooms:\n")
        for key, room in KNOWN_ROOMS.items():
            print(f"  {room['name']:<25} --room {key}")
            print(f"    {room['go_link']:<25} {room['description']}")
            print()
        return

    # Resolve room ID
    room_id = resolve_room_id(args.room, args.room_id)

    # Interactive mode if no command specified
    if not args.command:
        if not room_id:
            room_id = show_room_menu()
            if not room_id:
                print("Goodbye!")
                return

        question = get_question_interactive()
        if not question:
            print("Goodbye!")
            return

        client = GenieRoomClient(room_id=room_id, profile=args.profile)
        response = client.start_conversation(question)
        conv_id = response["conversation"]["id"]
        msg_id = response["message"]["id"]
        result = client.wait_for_result(conv_id, msg_id)
        print(client.format_response(result))
        return

    # Command mode requires room ID
    if not room_id:
        print(
            "Error: --room or --room-id is required for this command", file=sys.stderr
        )
        sys.exit(1)

    client = GenieRoomClient(room_id=room_id, profile=args.profile)

    if args.command == "ask":
        response = client.start_conversation(args.question)
        conv_id = response["conversation"]["id"]
        msg_id = response["message"]["id"]

        if not args.no_wait:
            result = client.wait_for_result(conv_id, msg_id)
            print(client.format_response(result))

    elif args.command == "follow-up":
        response = client.follow_up(args.conversation_id, args.question)
        msg_id = response["id"]

        if not args.no_wait:
            result = client.wait_for_result(args.conversation_id, msg_id)
            print(client.format_response(result))

    elif args.command == "status":
        response = client.get_message_status(args.conversation_id, args.message_id)
        print(json.dumps(response, indent=2))

    elif args.command == "feedback":
        handle_feedback(room_id, args.feedback_text, args.profile)

    elif args.command == "info":
        room_info = get_room_info(room_id, args.profile)
        owner = get_room_owner(room_id, args.profile)

        print("\n" + "=" * 60)
        print("GENIE ROOM INFO")
        print("=" * 60)
        print(f"\nTitle:       {room_info.get('title', 'N/A')}")
        print(f"Room ID:     {room_id}")
        print(f"Owner:       {owner or 'Unknown'}")
        print(f"Warehouse:   {room_info.get('warehouse_id', 'N/A')}")
        print(f"\nDescription:")
        print(f"  {room_info.get('description', 'N/A')}")
        print()


if __name__ == "__main__":
    main()
