# Frontend Code Patterns for APX

Reference templates for frontend development. **Only consult when writing frontend code.**

## List Page Template (routes/_sidebar/entities.tsx)

```typescript
import { createFileRoute, Link } from "@tanstack/react-router";
import { Suspense } from "react";
import { useListEntitiesSuspense, EntityStatus } from "@/lib/api";
import { selector } from "@/lib/selector";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

export const Route = createFileRoute("/_sidebar/entities")({
  component: () => (
    <div className="container mx-auto py-8">
      <Card>
        <CardHeader>
          <CardTitle>Entities</CardTitle>
        </CardHeader>
        <CardContent>
          <Suspense fallback={<TableSkeleton />}>
            <EntitiesTable />
          </Suspense>
        </CardContent>
      </Card>
    </div>
  ),
});

function EntitiesTable() {
  const { data: entities } = useListEntitiesSuspense(selector());

  return (
    <div className="rounded-md border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Number</TableHead>
            <TableHead>Title</TableHead>
            <TableHead>Status</TableHead>
            <TableHead className="text-right">Total</TableHead>
            <TableHead>Created</TableHead>
            <TableHead className="text-right">Actions</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {entities.length === 0 ? (
            <TableRow>
              <TableCell colSpan={6} className="text-center text-muted-foreground">
                No items found
              </TableCell>
            </TableRow>
          ) : (
            entities.map((entity) => (
              <TableRow key={entity.id}>
                <TableCell className="font-medium">{entity.entity_number}</TableCell>
                <TableCell>{entity.title}</TableCell>
                <TableCell>
                  <Badge className={getStatusColor(entity.status)}>
                    {entity.status}
                  </Badge>
                </TableCell>
                <TableCell className="text-right">{formatCurrency(entity.total)}</TableCell>
                <TableCell>{formatDate(entity.created_at)}</TableCell>
                <TableCell className="text-right">
                  <Link
                    to="/entities/$entityId"
                    params={{ entityId: entity.id }}
                    className="text-primary hover:underline"
                  >
                    View
                  </Link>
                </TableCell>
              </TableRow>
            ))
          )}
        </TableBody>
      </Table>
    </div>
  );
}

function TableSkeleton() {
  return (
    <div className="rounded-md border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Number</TableHead>
            <TableHead>Title</TableHead>
            <TableHead>Status</TableHead>
            <TableHead className="text-right">Total</TableHead>
            <TableHead>Created</TableHead>
            <TableHead className="text-right">Actions</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {[...Array(4)].map((_, i) => (
            <TableRow key={i}>
              <TableCell><Skeleton className="h-4 w-32" /></TableCell>
              <TableCell><Skeleton className="h-4 w-40" /></TableCell>
              <TableCell><Skeleton className="h-6 w-20" /></TableCell>
              <TableCell className="text-right"><Skeleton className="h-4 w-16 ml-auto" /></TableCell>
              <TableCell><Skeleton className="h-4 w-36" /></TableCell>
              <TableCell className="text-right"><Skeleton className="h-4 w-20 ml-auto" /></TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}

// Helper functions
const getStatusColor = (status: EntityStatus) => {
  const colors = {
    status_1: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300",
    status_2: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300",
  };
  return colors[status] || "bg-gray-100 text-gray-800";
};

const formatDate = (dateString: string) => {
  return new Date(dateString).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
};

const formatCurrency = (amount: number) => {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(amount);
};
```

## Detail Page Template (routes/_sidebar/entities.$entityId.tsx)

```typescript
import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { Suspense } from "react";
import { useGetEntitySuspense, useUpdateEntity, useDeleteEntity } from "@/lib/api";
import { selector } from "@/lib/selector";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { ArrowLeft } from "lucide-react";

export const Route = createFileRoute("/_sidebar/entities/$entityId")({
  component: () => (
    <div className="container mx-auto py-8">
      <Suspense fallback={<DetailSkeleton />}>
        <EntityDetail />
      </Suspense>
    </div>
  ),
});

function EntityDetail() {
  const { entityId } = Route.useParams();
  const navigate = useNavigate();
  const { data: entity } = useGetEntitySuspense(entityId, selector());

  const updateMutation = useUpdateEntity();
  const deleteMutation = useDeleteEntity();

  const handleDelete = async () => {
    if (!confirm("Are you sure you want to delete this item?")) return;

    try {
      await deleteMutation.mutateAsync({ entityId: entity.id });
      navigate({ to: "/entities" });
    } catch (error) {
      console.error("Failed to delete:", error);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link to="/entities">
            <Button variant="outline" size="icon">
              <ArrowLeft className="h-4 w-4" />
            </Button>
          </Link>
          <div>
            <h1 className="text-3xl font-bold">{entity.entity_number}</h1>
            <p className="text-muted-foreground">Entity Details</p>
          </div>
        </div>
        <Button
          variant="destructive"
          onClick={handleDelete}
          disabled={deleteMutation.isPending}
        >
          {deleteMutation.isPending ? "Deleting..." : "Delete"}
        </Button>
      </div>

      {/* Content Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Information</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            <div>
              <p className="text-sm font-medium text-muted-foreground">Title</p>
              <p className="text-base">{entity.title}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-muted-foreground">Status</p>
              <p className="text-base">{entity.status}</p>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Items</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              {entity.items.map((item) => (
                <div key={item.id} className="flex justify-between">
                  <span>{item.name}</span>
                  <span className="font-medium">{formatCurrency(item.value)}</span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function DetailSkeleton() {
  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Skeleton className="h-10 w-10" />
        <div>
          <Skeleton className="h-8 w-48 mb-2" />
          <Skeleton className="h-4 w-32" />
        </div>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {[...Array(2)].map((_, i) => (
          <Card key={i}>
            <CardHeader>
              <Skeleton className="h-6 w-32" />
            </CardHeader>
            <CardContent className="space-y-2">
              <Skeleton className="h-4 w-full" />
              <Skeleton className="h-4 w-3/4" />
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}

const formatCurrency = (amount: number) => {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(amount);
};
```

## Navigation Update (routes/_sidebar/route.tsx)

Add to `navItems` array:

```typescript
import { Package } from "lucide-react";  // Choose appropriate icon

const navItems = [
  {
    to: "/entities",
    label: "Entities",
    icon: <Package size={16} />,
    match: (path: string) => path.startsWith("/entities"),
  },
  // ... existing items
];
```

## Common Formatters

```typescript
// Currency
const formatCurrency = (amount: number) => {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(amount);
};

// Date with time
const formatDate = (dateString: string) => {
  return new Date(dateString).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
};

// Date only
const formatDateOnly = (dateString: string) => {
  return new Date(dateString).toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
};

// Number with commas
const formatNumber = (num: number) => {
  return new Intl.NumberFormat("en-US").format(num);
};
```

## Status Badge Colors

```typescript
const getStatusColor = (status: string) => {
  const colors: Record<string, string> = {
    pending: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300",
    processing: "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300",
    active: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300",
    completed: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300",
    cancelled: "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300",
    inactive: "bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300",
  };
  return colors[status] || "bg-gray-100 text-gray-800";
};
```

## Mutation Pattern with Error Handling

```typescript
const createMutation = useCreateEntity();

const handleCreate = async (data: EntityIn) => {
  try {
    const result = await createMutation.mutateAsync({ data });
    // Success - navigate or show message
    navigate({ to: `/entities/${result.data.id}` });
  } catch (error) {
    console.error("Failed to create:", error);
    // Show error to user
  }
};
```

## Performance Patterns

### TanStack Query Cache Presets

Define cache presets for different data freshness requirements:

```typescript
// lib/query-config.ts
export const queryPresets = {
  // Live data - aggressive refresh (running jobs, active status)
  live: {
    staleTime: 10 * 1000,      // 10 seconds
    gcTime: 60 * 1000,         // 1 minute
    refetchOnWindowFocus: true,
  },
  // Semi-live - moderate refresh (dashboards, summaries)
  semiLive: {
    staleTime: 60 * 1000,      // 1 minute
    gcTime: 5 * 60 * 1000,     // 5 minutes
    refetchOnWindowFocus: true,
  },
  // Slow - infrequent refresh (alerts, costs - expensive queries)
  slow: {
    staleTime: 10 * 60 * 1000, // 10 minutes
    gcTime: 30 * 60 * 1000,    // 30 minutes
    refetchOnWindowFocus: false,
  },
  // Static - rarely changes (user info, presets)
  static: {
    staleTime: Infinity,
    gcTime: 60 * 60 * 1000,    // 1 hour
    refetchOnWindowFocus: false,
  },
};

// Query keys factory for cache sharing
export const queryKeys = {
  alerts: {
    all: ['alerts'] as const,
    byJob: (jobId: string) => ['alerts', 'job', jobId] as const,
  },
  jobs: {
    active: ['jobs', 'active'] as const,
    health: (workspace?: string) => ['health-metrics', workspace] as const,
  },
};

// Usage
const { data } = useQuery({
  queryKey: queryKeys.alerts.all,
  queryFn: () => fetchAlerts(),
  ...queryPresets.slow,
  refetchInterval: 60000, // Background refresh
});
```

### Table Virtualization for Large Datasets

Use @tanstack/react-virtual when rendering 100+ rows:

```typescript
import { useVirtualizer } from '@tanstack/react-virtual';

const VIRTUALIZATION_THRESHOLD = 100;
const ROW_HEIGHT = 56;

function VirtualizedTable({ items }: { items: Item[] }) {
  const tableContainerRef = useRef<HTMLDivElement>(null);
  const useVirtualization = items.length >= VIRTUALIZATION_THRESHOLD;

  const rowVirtualizer = useVirtualizer({
    count: useVirtualization ? items.length : 0,
    getScrollElement: () => tableContainerRef.current,
    estimateSize: () => ROW_HEIGHT,
    overscan: 10, // Render 10 extra rows above/below
  });

  if (!useVirtualization) {
    // Standard table for small datasets
    return <StandardTable items={items} />;
  }

  return (
    <div ref={tableContainerRef} style={{ maxHeight: '600px', overflow: 'auto' }}>
      <div style={{ height: `${rowVirtualizer.getTotalSize()}px`, position: 'relative' }}>
        <Table>
          <TableBody>
            {rowVirtualizer.getVirtualItems().map((virtualRow) => {
              const item = items[virtualRow.index];
              return (
                <TableRow
                  key={item.id}
                  style={{
                    position: 'absolute',
                    top: 0,
                    left: 0,
                    width: '100%',
                    height: `${virtualRow.size}px`,
                    transform: `translateY(${virtualRow.start}px)`,
                  }}
                >
                  <ItemRow item={item} />
                </TableRow>
              );
            })}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}
```

### Route Prefetching with TanStack Router

Prefetch adjacent page data during navigation:

```typescript
// routeTree.gen.tsx
import { QueryClient } from '@tanstack/react-query';

let queryClientRef: QueryClient | null = null;
export const setQueryClient = (qc: QueryClient) => { queryClientRef = qc };

const prefetchAdjacentPages = async (currentPath: string) => {
  if (!queryClientRef) return;

  const adjacentPaths: Record<string, string[]> = {
    '/dashboard': ['/jobs', '/alerts'],
    '/jobs': ['/dashboard', '/alerts'],
    '/alerts': ['/jobs', '/historical'],
  };

  const adjacent = adjacentPaths[currentPath] || [];

  if (adjacent.includes('/jobs')) {
    queryClientRef.prefetchQuery({
      queryKey: ['jobs', 'active'],
      queryFn: async () => {
        const res = await fetch('/api/jobs/active');
        return res.json();
      },
      ...queryPresets.semiLive,
    });
  }
};

// In route definition
const dashboardRoute = createRoute({
  getParentRoute: () => sidebarRoute,
  path: '/dashboard',
  component: Dashboard,
  loader: () => prefetchAdjacentPages('/dashboard'),
});

// In main.tsx - set queryClient reference
setQueryClient(queryClient);
```

### Cache Sharing Between Components

Share expensive queries across components to avoid N+1 queries:

```typescript
// Bad: Each row fetches its own alerts
function JobRow({ job }) {
  const { data: alerts } = useQuery({
    queryKey: ['alerts', job.id],  // ❌ N queries for N rows
    queryFn: () => fetchAlertsForJob(job.id),
  });
}

// Good: Fetch all alerts once, filter in component
function JobHealthTable({ jobs }) {
  // Fetch ALL alerts once at table level
  const { data: alertsData } = useQuery({
    queryKey: queryKeys.alerts.all,  // ✅ Single query, shared cache
    queryFn: () => fetchAlerts(),
    ...queryPresets.slow,
  });

  const allAlerts = alertsData?.alerts ?? [];

  return (
    <Table>
      {jobs.map((job) => (
        <JobRow
          key={job.id}
          job={job}
          alerts={allAlerts.filter(a => a.job_id === job.id)}
        />
      ))}
    </Table>
  );
}
```
