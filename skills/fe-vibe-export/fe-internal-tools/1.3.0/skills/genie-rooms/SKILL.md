---
name: genie-rooms
description: Query any Databricks Genie Room using natural language. Select from known internal Genie Rooms or provide your own room ID.
---

# Genie Rooms Skill

Query any Databricks Genie Room using natural language. This skill provides an interactive menu of known internal Genie Rooms, or you can provide your own room ID.

## Quick Start (Interactive)

Run the script without arguments to see available Genie Rooms:

```bash
python3 resources/genie_rooms.py
```

This displays a menu of known Genie Rooms. Select one or enter a custom room ID.

## Known Genie Rooms

The following internal Genie Rooms are pre-configured:

| # | Name | go/ Link | Description |
|---|------|----------|-------------|
| 1 | Global Genie | go/global_genie | GTM data - accounts, consumption, forecasting |
| 2 | Emerging Genie | go/emerging_genie | Emerging segment data |
| 3 | CME Genie | go/cme_genie | Commercial/Mid-Enterprise data |
| 4 | Retail Genie | go/retail_genie | Retail industry vertical |
| 5 | Global Retail Genie | go/global_retail_genie | Global retail data |
| 6 | HLS Genie | go/hls_genie | Healthcare & Life Sciences |
| 7 | Global HLS Genie | go/global_hls_genie | Global HLS data |
| 8 | FINS Genie | go/fins_genie | Financial Services |
| 9 | Regional FINS Genie | go/reg_fins_genie | Regional Financial Services |
| 10 | MFG Genie | go/mfg_genie | Manufacturing |
| 11 | LATAM Genie | go/latam_genie | Latin America region |
| 12 | CAN Genie | go/can_genie | Canada region |

**To request access:** [go/gtm_genie_access](http://go/gtm_genie_access)

## Prerequisites

1. **Databricks Authentication** - Run `/databricks-authentication` to configure credentials
2. **Genie Room Access** - Request access via [go/gtm_genie_access](http://go/gtm_genie_access)
3. **VPN** - Must be on Databricks VPN to access internal Genie Rooms

## Usage

### Interactive Mode (Recommended)

```bash
python3 resources/genie_rooms.py
```

You'll see:
```
Available Genie Rooms:
  1. Global Genie (go/global_genie) - GTM data
  2. Emerging Genie (go/emerging_genie) - Emerging segment
  3. CME Genie (go/cme_genie) - Commercial/Mid-Enterprise
  ...
  c. Enter custom room ID

Select a room (1-12 or 'c' for custom):
```

After selecting a room, enter your question when prompted.

### Direct Mode (with room ID)

```bash
python3 resources/genie_rooms.py --room-id <room-id> ask "Your question"
```

### Using go/ Links

You can also use the go/ link name directly:

```bash
python3 resources/genie_rooms.py --room global_genie ask "What is ARR for Acme Corp?"
python3 resources/genie_rooms.py --room hls_genie ask "Top HLS accounts by consumption"
```

### Follow-Up Questions

Genie maintains conversation context:

```bash
python3 resources/genie_rooms.py --room-id <room-id> follow-up <conversation-id> "Break that down by region"
```

### Room Info

Look up room details and owner:

```bash
python3 resources/genie_rooms.py --room-id <room-id> info
```

### Send Feedback to Room Owner

If you notice data quality issues, missing columns, or incorrect data in a Genie room, you can send feedback directly to the room owner:

```bash
python3 resources/genie_rooms.py --room-id <room-id> feedback "Your feedback message"
```

This will:
1. Look up the room metadata and owner
2. Ask how you'd like to send feedback (Slack DM or Email)
3. Prepare a formatted message for Claude to send

## Options

| Option | Description |
|--------|-------------|
| `--room` | Room name (e.g., `global_genie`, `hls_genie`) |
| `--room-id` | Full room ID (32-character hex string) |
| `--profile` | Databricks CLI profile (default: DEFAULT) |
| `--no-wait` | Submit question without waiting for results |

## Commands

| Command | Description |
|---------|-------------|
| `ask` | Ask a new question |
| `follow-up` | Ask a follow-up question in an existing conversation |
| `status` | Check the status of a message |
| `list` | List known Genie Rooms |
| `info` | Show room information and owner |
| `feedback` | Send feedback to the room owner |

## Example Workflows

### Account Research with Global Genie

```bash
# Interactive
python3 resources/genie_rooms.py
# Select 1 (Global Genie)
# Enter: "What is the ARR and consumption trend for Acme Corp?"

# Direct
python3 resources/genie_rooms.py --room global_genie ask "What is the ARR and consumption trend for Acme Corp?"
```

### Industry-Specific Queries

```bash
# Healthcare
python3 resources/genie_rooms.py --room hls_genie ask "Top 10 HLS accounts by GenAI consumption"

# Financial Services
python3 resources/genie_rooms.py --room fins_genie ask "Which FINS accounts have serverless adoption above 50%?"

# Retail
python3 resources/genie_rooms.py --room retail_genie ask "Retail accounts with highest MoM growth"
```

### Custom Room ID

If you have a Genie Room not in the list:

```bash
# Get room ID from URL: https://adb-xxx.xx.azuredatabricks.net/genie/rooms/01ef...
python3 resources/genie_rooms.py --room-id 01ef336cd40b11f2b4931415636694eb ask "Your question"
```

### Reporting Data Quality Issues

If you notice incorrect data in a Genie room:

```bash
# First, check room info and owner
python3 resources/genie_rooms.py --room-id 01eef9cd9a711b5d85bc76d49a281055 info

# Send feedback to the owner
python3 resources/genie_rooms.py --room-id 01eef9cd9a711b5d85bc76d49a281055 feedback "The emerging_data table includes Enterprise accounts like Anysphere and Block, not just Emerging segment accounts."
```

The feedback command will look up the room owner and let you send a Slack DM or email with your feedback.

## Best Practices

### Copy Account Names from SFDC
Always copy/paste the exact SFDC account name to avoid pulling incorrect data.

### Be Specific with Time Periods
- "in Q3 2024"
- "last 6 months"
- "between January and March 2024"

### Pre-populate for Demos
Queries can take 30+ seconds. For demos, pre-populate a chat to verify accuracy first.

### UC Data Lag
Unity Catalog adoption data has a 72-hour SLA. Exclude the last 2 days when querying UC metrics.

## Limitations

- **Query Timeout**: Complex queries may timeout after 120 seconds
- **Result Limit**: Responses limited to 5,000 rows
- **Rate Limits**: 5 queries per minute per workspace
- **VPN Required**: Must be on Databricks VPN for internal rooms
- **Data Not Included**: Users/logins, Contracts, AE Targets, UCOs, Pipeline Gen, Meetings, DAIS attendance

## Troubleshooting

### "Error calling Databricks API"
Ensure you're authenticated and on VPN:
```bash
/databricks-authentication
```

### "Permission denied"
Request access via [go/gtm_genie_access](http://go/gtm_genie_access)

### Azure Spend Questions
For Azure accounts, do NOT ask spend questions - it pulls $DBUs which differ from customer-visible amounts.

## Related Skills

- **`/databricks-authentication`** - Configure Databricks credentials
- **`/logfood-querier`** - Query GTM data using direct SQL
- **`/databricks-query`** - Execute raw SQL queries

## References

- [Genie Demo FAQ](http://go/genie_demo_faq)
- [Request Access](http://go/gtm_genie_access)
- [Genie Usage Dashboard](https://adb-2548836972759138.18.azuredatabricks.net/dashboardsv3/01ef1dcffe2b16a78107053e15cb2b2e/published)
- [Databricks Genie Conversation API](https://docs.databricks.com/en/genie/conversation-api.html)
