# APX Performance Optimization Patterns

Proven patterns from production APX apps (Job Monitor v1.3.0). **Consult when optimizing app performance.**

## Performance Baseline Targets

| Endpoint Type | Target | Acceptable | Slow |
|--------------|--------|------------|------|
| Simple queries | <500ms | <1s | >2s |
| Cached data | <200ms | <500ms | >1s |
| System table queries | <5s | <10s | >15s |
| Complex aggregations | <10s | <15s | >30s |

## Backend Optimizations

### 1. Response Caching (In-Memory)

```python
from functools import lru_cache
from datetime import datetime, timedelta

# Simple TTL cache implementation
class ResponseCache:
    def __init__(self, max_entries=50, default_ttl=300):
        self._cache = {}
        self.max_entries = max_entries
        self.default_ttl = default_ttl

    def get(self, key: str) -> Any | None:
        if key in self._cache:
            value, expiry = self._cache[key]
            if datetime.now() < expiry:
                return value
            del self._cache[key]
        return None

    def set(self, key: str, value: Any, ttl: int | None = None):
        ttl = ttl or self.default_ttl
        self._cache[key] = (value, datetime.now() + timedelta(seconds=ttl))

response_cache = ResponseCache()

# TTL tiers based on data volatility
TTL_LIVE = 60        # Running jobs, active alerts
TTL_FAST = 120       # Alert counts, summaries
TTL_STANDARD = 300   # Health metrics, job lists
TTL_SLOW = 600       # Costs, historical data
```

### 2. GZip Compression

```python
from starlette.middleware.gzip import GZipMiddleware

app = FastAPI()
app.add_middleware(GZipMiddleware, minimum_size=500)
```

**Impact**: Reduces transfer size by 60-80% for JSON responses.

### 3. Selective Query Execution

```python
# Bad: Run all queries regardless of request
async def get_alerts():
    failure_alerts = await _generate_failure_alerts()
    sla_alerts = await _generate_sla_alerts()
    cost_alerts = await _generate_cost_alerts()
    return failure_alerts + sla_alerts + cost_alerts

# Good: Only run requested queries
async def get_alerts(category: list[str] | None = None):
    tasks = []
    if not category or "failure" in category:
        tasks.append(_generate_failure_alerts())
    if not category or "sla" in category:
        tasks.append(_generate_sla_alerts())
    results = await asyncio.gather(*tasks)
    return [alert for result in results for alert in result]
```

**Impact**: Single-category queries can be 10-20x faster.

### 4. Delta Cache Tables

Pre-aggregate slow queries into Delta tables with a refresh job:

```python
# Cache refresh job (runs every 5-15 minutes)
def refresh_cache():
    spark.sql("""
        INSERT OVERWRITE job_monitor.cache.health_metrics
        SELECT job_id, success_rate, failure_count, ...
        FROM system.lakeflow.job_run_timeline
        WHERE period_start_time >= current_date() - INTERVAL 7 DAYS
        GROUP BY job_id
    """)

# API queries cache table (fast) instead of system tables (slow)
async def get_health_metrics(ws):
    cached = await query_health_cache(ws)
    if cached:
        return cached  # ~2s vs ~13s from system tables
    return await query_system_tables(ws)  # Fallback
```

**Impact**: 5-10x faster for complex aggregations.

### 5. Parallel Query Execution

```python
# Good: Run independent queries in parallel
async def get_dashboard_data():
    health, costs, alerts = await asyncio.gather(
        get_health_metrics(),
        get_cost_summary(),
        get_alerts(),
    )
    return {"health": health, "costs": costs, "alerts": alerts}
```

### 6. API Timeouts

```python
# Prevent hanging requests from blocking UI
async def call_jobs_api(ws, job_id: str, timeout_seconds: int = 30):
    try:
        return await asyncio.wait_for(
            asyncio.to_thread(ws.jobs.get, job_id),
            timeout=timeout_seconds
        )
    except asyncio.TimeoutError:
        logger.warning(f"Jobs API timeout for {job_id}")
        return None
```

## Frontend Optimizations

### 1. TanStack Query Tiered Caching

```typescript
export const queryPresets = {
  // Historical data - never changes
  static: {
    staleTime: Infinity,
    gcTime: 30 * 60 * 1000,  // 30 min
    refetchOnWindowFocus: false,
    refetchOnMount: false,
  },

  // Semi-live data - system table latency (5-15 min)
  semiLive: {
    staleTime: 5 * 60 * 1000,   // 5 min
    gcTime: 15 * 60 * 1000,     // 15 min
    refetchOnWindowFocus: true,
  },

  // Slow endpoints - reduce load
  slow: {
    staleTime: 10 * 60 * 1000,  // 10 min
    gcTime: 30 * 60 * 1000,     // 30 min
    refetchOnWindowFocus: false,
  },

  // Live data - needs freshness
  live: {
    staleTime: 60 * 1000,       // 1 min
    gcTime: 5 * 60 * 1000,      // 5 min
    refetchOnWindowFocus: true,
  },
}
```

### 2. Route Prefetching

```typescript
// routeTree.gen.tsx
const prefetchAdjacentPages = async (currentPath: string) => {
  if (!queryClientRef) return

  const adjacentPaths: Record<string, string[]> = {
    '/dashboard': ['/job-health', '/running-jobs'],
    '/running-jobs': ['/dashboard', '/job-health'],
  }

  const adjacent = adjacentPaths[currentPath] || []

  if (adjacent.includes('/running-jobs')) {
    queryClientRef.prefetchQuery({
      queryKey: ['active-jobs'],
      queryFn: () => fetch('/api/jobs/active').then(r => r.json()),
      ...queryPresets.live,
    })
  }
}

const dashboardRoute = createRoute({
  path: '/dashboard',
  loader: () => prefetchAdjacentPages('/dashboard'),
})
```

### 3. IndexedDB Cache Persistence

```typescript
import { PersistQueryClientProvider } from '@tanstack/react-query-persist-client'
import { get, set, del } from 'idb-keyval'

const IDB_KEY = 'app-query-cache'
const MAX_AGE = 24 * 60 * 60 * 1000  // 24 hours

const idbPersister = {
  persistClient: async (client) => await set(IDB_KEY, client),
  restoreClient: async () => await get(IDB_KEY),
  removeClient: async () => await del(IDB_KEY),
}

// In main.tsx
<PersistQueryClientProvider
  client={queryClient}
  persistOptions={{
    persister: idbPersister,
    maxAge: MAX_AGE,
    dehydrateOptions: {
      // Only persist queries with gcTime >= 5 minutes
      shouldDehydrateQuery: (query) => (query.gcTime ?? 0) >= 5 * 60 * 1000,
    },
  }}
>
```

**Impact**: Instant load on return visits - data survives page refresh.

### 4. Table Virtualization

```typescript
import { useVirtualizer } from '@tanstack/react-virtual'

function VirtualizedTable({ data }) {
  const parentRef = useRef<HTMLDivElement>(null)

  const virtualizer = useVirtualizer({
    count: data.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 56,  // Row height
    overscan: 10,
  })

  return (
    <div ref={parentRef} style={{ height: '600px', overflow: 'auto' }}>
      <div style={{ height: virtualizer.getTotalSize() }}>
        {virtualizer.getVirtualItems().map((virtualRow) => (
          <TableRow key={virtualRow.key} data={data[virtualRow.index]} />
        ))}
      </div>
    </div>
  )
}
```

**Impact**: Handle 4000+ rows smoothly (only renders visible rows).

## Known Performance Issues

### Workspace-Filtered Queries

**Problem**: Delta cache doesn't support workspace filtering:
```python
# When workspace_id is specified, cache is bypassed
use_delta_cache = settings.use_cache and (not workspace_id or workspace_id == "all")
```

**Impact**: 46s response time vs 2s with cache.

**Solution**: Add workspace_id column to cache tables (requires schema change).

### System Table Latency

System tables have 5-15 minute data latency. Don't expect real-time data.

**Solution**: Use Jobs API for real-time data, system tables for historical/aggregated data.

## Performance Testing

### Chrome MCP for Interactive Testing

```typescript
// Navigate and measure
mcp__chrome-devtools__navigate_page({ url: 'https://app-url/dashboard' })
mcp__chrome-devtools__wait_for({ text: ['Total Jobs', 'Loading'] })

// Get timing data
mcp__chrome-devtools__evaluate_script({
  function: `() => {
    return performance.getEntriesByType('resource')
      .filter(e => e.name.includes('/api/'))
      .map(e => ({
        url: e.name.split('?')[0],
        duration: Math.round(e.duration),
        transferSize: e.transferSize,
        decodedSize: e.decodedBodySize
      }))
  }`
})
```

### Backend Load Testing

```bash
# Quick performance check
for endpoint in /api/me /api/alerts /api/health-metrics; do
  echo "Testing $endpoint"
  time curl -s "https://app-url$endpoint" > /dev/null
done
```

## Optimization Checklist

- [ ] Response caching with TTL tiers
- [ ] GZip compression enabled
- [ ] Selective query execution
- [ ] Delta cache tables for slow queries
- [ ] Parallel query execution
- [ ] API timeouts configured
- [ ] TanStack Query presets configured
- [ ] Route prefetching for adjacent pages
- [ ] IndexedDB persistence for return visits
- [ ] Table virtualization for large datasets
