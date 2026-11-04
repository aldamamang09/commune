import { test, expect } from "@playwright/test";
import { fetchAllRows } from "@/lib/paginated-read";

// Isolated unit tests for the pagination helper. The fake "table" is an
// in-memory array sorted by (created_at, id) exactly like the production
// queries, served through a cap-enforcing pager - no database, no network.

type Row = { id: string; created_at: string };

function makeTable(n: number, tie: (i: number) => boolean | "all" = () => false): Row[] {
  const base = Date.parse("2026-10-25T05:00:00.000Z");
  return Array.from({ length: n }, (_, i) => ({
    id: `row-${String(i).padStart(5, "0")}`,
    // tie(i) === true -> same timestamp as the previous row; "all" -> one timestamp for every row
    created_at: new Date(base + (tie(i) === "all" ? 0 : (tie(i) ? Math.max(i - 1, 0) : i) * 1000)).toISOString(),
  }));
}

function sorted(rows: Row[], desc = false) {
  return [...rows].sort((a, b) => {
    const k = a.created_at === b.created_at ? (a.id < b.id ? -1 : 1) : a.created_at < b.created_at ? -1 : 1;
    return desc ? -k : k;
  });
}

type Pager = {
  query: (from: number, to: number) => Promise<{ data: Row[]; error: null; count: number }>;
  calls: number;
  maxInFlight: number;
};

function pager(table: Row[], cap = 1000, opts: { desc?: boolean; onCall?: (n: number) => void } = {}): Pager {
  const state = { calls: 0, maxInFlight: 0, inFlight: 0 };
  const view = () => sorted(table, opts.desc);
  const query: Pager["query"] = async (from, to) => {
    state.calls += 1;
    state.inFlight += 1;
    state.maxInFlight = Math.max(state.maxInFlight, state.inFlight);
    opts.onCall?.(state.calls);
    await new Promise((resolve) => setTimeout(resolve, 2)); // let parallel requests overlap
    const rows = view();
    const data = rows.slice(from, Math.min(to + 1, from + cap));
    state.inFlight -= 1;
    return { data, error: null, count: rows.length };
  };
  return Object.assign(state, { query }) as unknown as Pager;
}

const ids = (rows: Row[]) => rows.map((row) => row.id);

test("returns every row exactly once, in order, at the sizes seen in production", async () => {
  for (const n of [0, 1, 999, 1000, 1001, 1075, 1813, 2000, 2001, 5001]) {
    const table = makeTable(n);
    const result = await fetchAllRows("t", pager(table).query);
    expect(result.error).toBeNull();
    const got = ids(result.data!);
    expect(got, `n=${n}: count`).toHaveLength(n);
    expect(new Set(got).size, `n=${n}: duplicates`).toBe(n);
    expect(got, `n=${n}: order`).toEqual(ids(sorted(table)));
  }
});

test("equal timestamps at and around the page boundary lose and repeat nothing", async () => {
  const scenarios: [string, Row[]][] = [
    ["every row shares one timestamp, 1075 rows", makeTable(1075, () => "all")],
    ["every row shares one timestamp, 1813 rows", makeTable(1813, () => "all")],
    // production: the 1000th and 1001st order_items had the identical created_at
    ["rows 990-1010 tie with each other", makeTable(1075, (i) => i >= 991 && i <= 1010)],
    ["many pairs of ties", makeTable(2500, (i) => i % 2 === 1)],
  ];
  for (const [name, table] of scenarios) {
    const result = await fetchAllRows("t", pager(table).query);
    expect(result.error).toBeNull();
    expect(ids(result.data!), name).toEqual(ids(sorted(table)));
  }
});

test("descending order (orders query) is also complete and ordered", async () => {
  const table = makeTable(1813, (i) => i % 3 === 0);
  const result = await fetchAllRows("orders", pager(table, 1000, { desc: true }).query);
  expect(ids(result.data!)).toEqual(ids(sorted(table, true)));
});

test("a row inserted between page fetches never causes a missing row", async () => {
  // Newest-first (orders): an insert after page 1 shifts later rows by one, so
  // the boundary row repeats. It must be de-duplicated and nothing may be lost.
  const table = makeTable(1500);
  const p = pager(table, 1000, {
    desc: true,
    onCall: (n) => {
      if (n === 1) table.push({ id: "row-99999", created_at: "2026-10-26T00:00:00.000Z" });
    },
  });
  const result = await fetchAllRows("orders", p.query);
  const got = new Set(ids(result.data!));
  expect(got.size).toBe(result.data!.length); // no duplicates
  for (const row of makeTable(1500)) expect(got.has(row.id), row.id).toBe(true); // nothing missing
});

test("an error on any page is returned, never a silently partial list", async () => {
  const table = makeTable(3500);
  for (const failingCall of [1, 2, 3, 4]) {
    const base = pager(table);
    let n = 0;
    const result = await fetchAllRows("order_items", async (from, to) => {
      n += 1;
      if (n === failingCall) return { data: null, error: { message: "simulated outage" }, count: null };
      return base.query(from, to);
    });
    expect(result.data, `fail on call ${failingCall}`).toBeNull();
    expect(result.error?.message).toBe("simulated outage");
  }
});

test("refuses to guess when the server does not return a row count", async () => {
  const result = await fetchAllRows("t", async () => ({ data: makeTable(5), error: null }));
  expect(result.data).toBeNull();
  expect(result.error?.message).toMatch(/row count was not returned/);
});

test("stays complete when the server cap is lower than the requested page size", async () => {
  for (const cap of [1, 250, 400, 999]) {
    const table = makeTable(1075);
    const result = await fetchAllRows("t", pager(table, cap).query);
    expect(ids(result.data!), `cap=${cap}`).toEqual(ids(sorted(table)));
  }
});

test("request count and concurrency stay bounded", async () => {
  const cases: [number, number][] = [[0, 1], [999, 1], [1000, 1], [1001, 2], [1075, 2], [1813, 2], [5001, 6]];
  for (const [n, expectedCalls] of cases) {
    const p = pager(makeTable(n));
    await fetchAllRows("t", p.query);
    expect(p.calls, `n=${n}`).toBe(expectedCalls);
  }
  const big = pager(makeTable(20000));
  await fetchAllRows("t", big.query);
  expect(big.maxInFlight).toBeLessThanOrEqual(5);
});
