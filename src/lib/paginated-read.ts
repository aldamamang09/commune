// PostgREST (Supabase) silently truncates every response to the project's
// "max rows" setting (1000 here), even for a plain select("*") with no limit.
// An unpaginated read of a growing table therefore drops its tail without any
// error - on 2026-10-25 that hid the newest order_items/usage_logs from the
// Admin dashboard (orders showed no items, Total Sold under-reported).
//
// fetchAllRows reads page 1 to learn the exact row count and the server's real
// page size, then fetches the remaining pages in parallel (bounded), so latency
// stays at two round trips however large the table grows. The stride is the
// number of rows page 1 actually returned, so it stays correct even if the
// server's cap is lower than the requested page size.

export type PageQuery<T> = (
  from: number,
  to: number,
) => PromiseLike<{
  data: T[] | null;
  error: { message: string } | null;
  count?: number | null;
}>;

export const READ_PAGE_SIZE = 1000;
const MAX_PARALLEL_PAGES = 5;

type Result<T> =
  | { data: T[]; error: null }
  | { data: null; error: { message: string } };

// The query must be ordered by a unique, stable key (e.g. created_at then id)
// and must request { count: "exact" } so the loop knows where the table ends.
export async function fetchAllRows<T extends { id: string }>(
  table: string,
  query: PageQuery<T>,
  pageSize = READ_PAGE_SIZE,
): Promise<Result<T>> {
  const first = await query(0, pageSize - 1);
  if (first.error) return { data: null, error: first.error };
  if (typeof first.count !== "number") {
    return {
      data: null,
      error: { message: `${table}: row count was not returned; refusing to guess the end of the table` },
    };
  }

  const total = first.count;
  const firstPage = first.data ?? [];
  const pages: T[][] = [firstPage];
  const stride = firstPage.length;

  if (stride > 0 && stride < total) {
    const offsets: number[] = [];
    for (let from = stride; from < total; from += stride) offsets.push(from);
    for (let i = 0; i < offsets.length; i += MAX_PARALLEL_PAGES) {
      const batch = await Promise.all(
        offsets.slice(i, i + MAX_PARALLEL_PAGES).map((from) => query(from, from + stride - 1)),
      );
      for (const result of batch) {
        if (result.error) return { data: null, error: result.error };
        pages.push(result.data ?? []);
      }
    }
  }

  // A concurrent insert can shift offsets between page fetches and repeat the
  // row at a page boundary; keep the first occurrence of each id.
  const rows: T[] = [];
  const seen = new Set<string>();
  for (const page of pages) {
    for (const row of page) {
      if (seen.has(row.id)) continue;
      seen.add(row.id);
      rows.push(row);
    }
  }
  return { data: rows, error: null };
}
