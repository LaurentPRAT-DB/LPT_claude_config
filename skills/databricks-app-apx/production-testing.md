# Production Testing & Performance Optimization

This guide covers production-grade testing and performance optimization for deployed Databricks Apps, based on real-world learnings from monitoring dashboard implementations.

## Load Testing with Chrome DevTools MCP

### Prerequisites

Start Chrome with remote debugging:
```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222
```

Log in to your deployed app in that Chrome instance first.

### Load Test Script Pattern

Create `tests/load-test.js`:

```javascript
// Load test for Databricks Apps
const DURATION_HOURS = parseFloat(process.argv[2] || 1);
const TEST_CONFIG = {
  apiEndpoints: [
    { name: 'Health', path: '/api/health', staleTime: 60000 },
    { name: 'User Info', path: '/api/me', staleTime: 300000 },
    { name: 'List Items', path: '/api/items', staleTime: 60000 },
    { name: 'Slow Query', path: '/api/slow-query?days=30', staleTime: 600000 },
  ],
  pages: ['/', '/dashboard', '/alerts', '/settings'],
  testInterval: 60000,  // 1 minute between full cycles
};

// Track metrics
const metrics = {
  apiCalls: {},
  pageLoads: {},
  cacheHits: 0,
  cacheMisses: 0,
  errors: [],
};

async function testApiEndpoint(endpoint) {
  const start = Date.now();
  try {
    const response = await fetch(endpoint.path);
    const duration = Date.now() - start;

    if (!metrics.apiCalls[endpoint.name]) {
      metrics.apiCalls[endpoint.name] = { times: [], errors: 0 };
    }
    metrics.apiCalls[endpoint.name].times.push(duration);

    // Check cache header
    if (response.headers.get('x-cache') === 'HIT') {
      metrics.cacheHits++;
    } else {
      metrics.cacheMisses++;
    }

    return { success: true, duration };
  } catch (error) {
    metrics.errors.push({ endpoint: endpoint.name, error: error.message });
    return { success: false, error };
  }
}

function generateReport() {
  console.log('\n=== Load Test Report ===\n');

  for (const [name, data] of Object.entries(metrics.apiCalls)) {
    const times = data.times;
    const avg = times.reduce((a, b) => a + b, 0) / times.length;
    const p95 = times.sort((a, b) => a - b)[Math.floor(times.length * 0.95)];

    console.log(`${name}:`);
    console.log(`  Avg: ${avg.toFixed(0)}ms | P95: ${p95}ms | Calls: ${times.length}`);
  }

  const cacheRate = metrics.cacheHits / (metrics.cacheHits + metrics.cacheMisses) * 100;
  console.log(`\nCache Hit Rate: ${cacheRate.toFixed(1)}%`);
  console.log(`Errors: ${metrics.errors.length}`);
}
```

### Running Load Tests

```bash
# Quick 6-minute test
node tests/load-test.js 0.1

# 1-hour production test
node tests/load-test.js 1

# Extended 4-hour test
node tests/load-test.js 4
```

## Performance Optimization Patterns

### Frontend: TanStack Query Caching

Define cache presets for different endpoint characteristics:

```typescript
// src/lib/query-presets.ts
export const queryPresets = {
  // Fast endpoints (< 500ms)
  default: {
    staleTime: 60 * 1000,      // 1 min
    gcTime: 5 * 60 * 1000,     // 5 min
  },

  // Slow endpoints (> 5s)
  slow: {
    staleTime: 10 * 60 * 1000,  // 10 min
    gcTime: 30 * 60 * 1000,     // 30 min
    refetchOnWindowFocus: false,
    refetchOnMount: false,
  },

  // Real-time data
  realtime: {
    staleTime: 10 * 1000,      // 10 sec
    refetchInterval: 30 * 1000, // Auto-refresh every 30s
  },
};

// Usage
const { data } = useQuery({
  queryKey: ['slow-data'],
  queryFn: fetchSlowData,
  ...queryPresets.slow,
});
```

### Backend: Selective Query Execution

Only run queries the client actually needs:

```python
# routes/alerts.py
@router.get("/alerts")
async def get_alerts(
    category: Optional[str] = None,  # "failure", "sla", "cost", or None for all
    request: Request = None,
):
    """
    Optimization: Only execute queries for requested categories.

    Before: 4 parallel queries always (~19s)
    After:  1 query when category specified (~3-5s)
    """
    results = []

    if category is None or category == "failure":
        results.extend(await get_failure_alerts(request))

    if category is None or category == "sla":
        results.extend(await get_sla_alerts(request))

    if category is None or category == "cost":
        results.extend(await get_cost_alerts(request))

    return results
```

### Backend: Skip Expensive Operations

Make expensive operations opt-in:

```python
# routes/cost.py
@router.get("/cost-summary")
async def get_cost_summary(
    include_teams: bool = False,  # Default OFF - saves 20-30s
    request: Request = None,
):
    """
    Before: Always fetched team tags via 50+ Jobs API calls (~37s)
    After:  Skip by default, 5x faster (~7s)
    """
    summary = await get_base_cost_summary()

    if include_teams:
        # Expensive: makes N API calls for team tags
        summary = await enrich_with_team_data(summary)

    return summary
```

### Server-Side Caching with Cache Tables

For very slow queries (>10s), use materialized cache tables:

```python
# jobs/refresh_cache.py
"""
Scheduled job to refresh cache tables.
Run hourly via Databricks Workflows.
"""

def refresh_job_health_cache(spark):
    """Materialize expensive CTEs into cache table."""
    spark.sql("""
        CREATE OR REPLACE TABLE job_monitor.cache.job_health_cache AS
        SELECT
            job_id,
            job_name,
            -- Complex aggregations pre-computed
            SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failure_count,
            AVG(duration_ms) as avg_duration_ms,
            -- Window functions pre-computed
            LAG(duration_ms) OVER (PARTITION BY job_id ORDER BY start_time) as prev_duration
        FROM system.lakeflow.job_run_timeline
        WHERE start_time > current_date() - INTERVAL 30 DAYS
        GROUP BY job_id, job_name
    """)
```

Then query the cache instead of system tables:

```python
# Fast: ~2s instead of ~15s
async def get_job_health(request: Request):
    return await execute_query(
        "SELECT * FROM job_monitor.cache.job_health_cache",
        request
    )
```

## Performance Benchmarks

Track these metrics for production apps:

| Endpoint Type | Target | Warning | Critical |
|--------------|--------|---------|----------|
| Health check | < 100ms | > 500ms | > 1s |
| Simple list | < 500ms | > 2s | > 5s |
| Aggregation | < 3s | > 10s | > 30s |
| Cache hit rate | > 50% | < 30% | < 10% |

### Example Results After Optimization

| Endpoint | Before | After | Improvement |
|----------|--------|-------|-------------|
| Cost Summary | 37.7s | 7.8s | 5x faster |
| Alerts (single) | 19.3s | 3-5s | 4-6x faster |
| Health Metrics | 15.0s | 2.0s | 7x faster (with cache) |
| Cache hit rate | 4.9% | 50%+ | 10x better |

## Multi-Target Deployment Testing

When deploying to multiple workspaces, test each target:

```bash
# deploy.sh - includes post-deploy smoke tests
#!/bin/bash
TARGET="${1:-e2}"

case "$TARGET" in
  e2)   PROFILE="DEFAULT" ;;
  prod) PROFILE="DEMO WEST" ;;
  dev)  PROFILE="LPT_FREE_EDITION" ;;
esac

# Deploy
databricks bundle deploy -t "$TARGET"

# Get app URL
APP_URL=$(databricks apps get <app-name> -p "$PROFILE" | jq -r '.url')

# Smoke tests
echo "Testing $APP_URL..."
curl -s "$APP_URL/api/health" | jq -e '.status == "ok"'
curl -s "$APP_URL/api/me" | jq -e '.email != null'

echo "Deployment to $TARGET successful!"
```

## Troubleshooting Slow Endpoints

### 1. Identify Slow Queries

Check app logs for slow queries:
```bash
databricks apps logs <app-name> -p <profile> | grep -E "duration.*[0-9]{4,}ms"
```

### 2. Profile SQL Queries

Use EXPLAIN to understand query plans:
```sql
EXPLAIN FORMATTED
SELECT * FROM system.lakeflow.job_run_timeline
WHERE workspace_id = 1234567890
```

### 3. Check for N+1 Queries

Look for loops making API calls:
```python
# ❌ N+1 problem - 50+ API calls
for job in jobs:
    team = await get_job_tags(job.job_id)  # API call per job!

# ✅ Batch approach - 1 API call
job_ids = [j.job_id for j in jobs]
tags = await batch_get_job_tags(job_ids)
```

### 4. Verify OBO vs SP Auth

SP auth may have limited permissions causing retries or failures:
```python
# Check if using correct auth for system tables
logger.info(f"Using auth: {'OBO' if user_token else 'SP'}")
```

See [1-authorization.md](../databricks-app-python/1-authorization.md) for OBO gotchas.
