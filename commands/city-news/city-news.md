Search Google News for the latest news about a specific city.

Parse $ARGUMENTS as follows:
- The city name is the first part of the argument
- If the word "pull" is present in $ARGUMENTS, fetch the news directly (see below)
- If "pull" is not present, open the browser instead

Examples:
- `/user:city-news Paris` → opens browser with Google News for Paris
- `/user:city-news Paris pull` → fetches and displays news directly in Claude Code

---

**If "pull" is NOT in $ARGUMENTS:**
1. Replace spaces with "+" in the city name for URL encoding
2. Construct the URL: https://news.google.com/search?q=CITY_NAME&hl=en-US&gl=US&ceid=US:en
3. Open it in the browser by running: `open "URL"`
4. Confirm to the user: "Opened Google News results for [city name]."

---

**If "pull" IS in $ARGUMENTS:**
1. Replace spaces with "+" in the city name for URL encoding
2. Fetch and parse the RSS feed using this exact command (works on macOS):
```bash
curl -s "https://news.google.com/rss/search?q=CITY_NAME&hl=en-US&gl=US&ceid=US:en" | tr '\n' ' ' | sed 's/<item>/\n<item>/g' | tail -n +2 | head -12 | while IFS= read -r item; do
  title=$(echo "$item" | sed -n 's/.*<title>\([^<]*\)<\/title>.*/\1/p')
  link=$(echo "$item" | sed -n 's/.*<link>\([^<]*\)<\/link>.*/\1/p')
  pubDate=$(echo "$item" | sed -n 's/.*<pubDate>\([^<]*\)<\/pubDate>.*/\1/p')
  source=$(echo "$item" | sed 's/.*<source[^>]*>\([^<]*\)<\/source>.*/\1/' | grep -v '<item>')
  echo "TITLE: $title"
  echo "SOURCE: $source"
  echo "DATE: $pubDate"
  echo "LINK: $link"
  echo "---"
done
```
3. The command extracts for each article:
   - Title
   - Source
   - Publication date
   - Link
4. Display the results in a clean, readable format like:

### 📰 Latest News for [City Name]

1. **[Article Title]**
   🗞 Source | 📅 Date
   🔗 [Read more](link)

---

5. Summarize the top themes or topics found across the headlines.
