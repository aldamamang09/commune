import { test, expect } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { getFreshStore } from "@/lib/store";

// Regression for the 2026-10-25 incident: PostgREST caps every response at
// 1000 rows, and readStore used unpaginated selects, so the newest
// order_items/usage_logs never reached the Admin dashboard (orders loaded with
// no items; Total Sold under-reported).
//
// Everything here is isolated: fetch is replaced in-process by a fake PostgREST
// that enforces the row cap, serves only GETs, and throws on any other host or
// method. Nothing can reach a real Supabase project.

const MOCK_URL = "https://mock-incident.supabase.co";
type Row = Record<string, unknown>;

function buildDataset() {
  const orders: Row[] = [];
  const orderItems: Row[] = [];
  const usageLogs: Row[] = [];
  const itemCount = new Map<string, number>();
  const base = Date.parse("2026-10-25T05:00:00.000Z");

  for (let i = 1; i <= 561; i += 1) {
    const id = `ord-${String(i).padStart(4, "0")}`;
    const createdAt = new Date(base + i * 60_000).toISOString();
    orders.push({
      id, created_at: createdAt, barista_name: "Test", subtotal: 100, discount: 0,
      total: 100, payment_method: "cash", ticket_no: String(i).padStart(3, "0"),
      paid: 100, change: 0, voided: false, deleted_at: null, record_type: "Sale",
    });
    // 1-3 lines per order; all lines of an order share created_at, exactly as
    // rows inserted in one transaction do - so ties straddle page boundaries.
    const lines = (i % 3) + 1;
    itemCount.set(id, lines);
    for (let n = 1; n <= lines; n += 1) {
      orderItems.push({
        id: `${id}-item-${n}`, order_id: id, product_id_snapshot: "p1",
        name_snapshot: "Latte", qty: 1, price_snapshot: 100, created_at: createdAt,
        style: null, addons: [], service_mode: null,
      });
    }
    for (let n = 1; n <= 3; n += 1) {
      usageLogs.push({
        // empty order_item_id: normalizeStore only keeps item-linked usage logs
        // whose product has a configured recipe, which this fixture doesn't need.
        id: `${id}-inv${n}-usage`, order_id: id, order_item_id: "",
        inventory_item_id: `inv${n}`, item_name_snapshot: "x", used_amount: 1,
        unit: "g", created_at: createdAt,
      });
    }
  }
  return { orders, orderItems, usageLogs, itemCount };
}

type Fake = { requests: { method: string; url: string }[]; restore: () => void };

function installFakePostgrest(
  tables: Record<string, Row[]>,
  opts: { cap: number; failOnOffset?: { table: string; offset: number } },
): Fake {
  const realFetch = globalThis.fetch;
  const requests: Fake["requests"] = [];
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = new URL(typeof input === "string" ? input : input instanceof URL ? input.href : input.url);
    const method = (init?.method ?? "GET").toUpperCase();
    requests.push({ method, url: url.href });
    if (url.origin !== MOCK_URL || method !== "GET") {
      throw new Error(`Blocked non-mock request: ${method} ${url.href}`);
    }
    const table = url.pathname.replace("/rest/v1/", "");
    let rows = [...(tables[table] ?? [])];

    for (const [key, value] of url.searchParams) {
      if (["select", "order", "offset", "limit"].includes(key)) continue;
      if (value === "is.null") rows = rows.filter((r) => r[key] == null);
      else if (value.startsWith("eq.")) rows = rows.filter((r) => String(r[key]) === value.slice(3));
    }
    const order = (url.searchParams.get("order") ?? "").split(",").filter(Boolean).map((part) => {
      const [col, dir] = part.split(".");
      return { col, desc: dir === "desc" };
    });
    rows.sort((a, b) => {
      for (const { col, desc } of order) {
        const x = String(a[col]);
        const y = String(b[col]);
        if (x !== y) return (x < y ? -1 : 1) * (desc ? -1 : 1);
      }
      return 0;
    });

    const offset = Number(url.searchParams.get("offset") ?? 0);
    const limit = Math.min(Number(url.searchParams.get("limit") ?? Infinity), opts.cap);
    if (opts.failOnOffset && opts.failOnOffset.table === table && offset >= opts.failOnOffset.offset) {
      return new Response(JSON.stringify({ message: "simulated outage" }), { status: 500 });
    }
    const page = rows.slice(offset, offset + limit);
    const wantsCount = new Headers(init?.headers).get("Prefer")?.includes("count=exact");
    const headers: Record<string, string> = { "Content-Type": "application/json" };
    if (wantsCount) {
      headers["Content-Range"] = page.length ? `${offset}-${offset + page.length - 1}/${rows.length}` : `*/${rows.length}`;
    }
    return new Response(JSON.stringify(page), { status: 200, headers });
  }) as typeof fetch;
  return { requests, restore: () => { globalThis.fetch = realFetch; } };
}

function otherTables(): Record<string, Row[]> {
  return {
    staff_users: [{ id: "u1", username: "admin", password: "x", name: "Admin", role: "admin", title: "Owner", created_at: "2026-01-01T00:00:00.000Z" }],
    menu_categories: [{ id: "drinks", name: "Drinks", type: "drinks", created_at: "2026-01-01T00:00:00.000Z" }],
    menu_items: [{ id: "p1", name: "Latte", price: 100, category_id: "drinks", image: null, available: true, styles: ["iced"], addons: [], types: [], created_at: "2026-01-01T00:00:00.000Z" }],
  };
}

const saved = { url: process.env.SUPABASE_URL, key: process.env.SUPABASE_SECRET_KEY, role: process.env.SUPABASE_SERVICE_ROLE_KEY };
test.beforeAll(() => {
  process.env.SUPABASE_URL = MOCK_URL;
  process.env.SUPABASE_SECRET_KEY = "mock-key";
  process.env.SUPABASE_SERVICE_ROLE_KEY = "mock-key";
});
test.afterAll(() => {
  for (const [name, value] of [["SUPABASE_URL", saved.url], ["SUPABASE_SECRET_KEY", saved.key], ["SUPABASE_SERVICE_ROLE_KEY", saved.role]] as const) {
    if (value === undefined) delete process.env[name];
    else process.env[name] = value;
  }
});

test("control: the fake backend reproduces the 1000-row cap that caused the incident", async () => {
  const data = buildDataset();
  expect(data.orderItems.length).toBeGreaterThan(1000);
  const fake = installFakePostgrest({ ...otherTables(), order_items: data.orderItems }, { cap: 1000 });
  try {
    const client = createClient(MOCK_URL, "mock-key");
    const unpaginated = await client.from("order_items").select("*").order("created_at");
    expect(unpaginated.data).toHaveLength(1000); // the old readStore behaviour
  } finally {
    fake.restore();
  }
});

test("readStore returns every order, order item and usage log beyond the 1000-row cap", async () => {
  const data = buildDataset();
  expect(data.usageLogs.length).toBeGreaterThan(1000);
  const fake = installFakePostgrest(
    { ...otherTables(), orders: data.orders, order_items: data.orderItems, usage_logs: data.usageLogs },
    { cap: 1000 },
  );
  try {
    const store = await getFreshStore();
    expect(store.orders).toHaveLength(data.orders.length);
    expect(store.usageLogs).toHaveLength(data.usageLogs.length);
    const withoutItems = store.orders.filter((order) => order.items.length === 0);
    expect(withoutItems.map((order) => order.ticketNo)).toEqual([]);
    for (const order of store.orders) {
      expect(order.items, `order ${order.id}`).toHaveLength(data.itemCount.get(order.id)!);
    }
    // Newest order first, as the dashboard expects.
    expect(store.orders[0].id).toBe("ord-0561");
    // The read path must never write.
    expect(fake.requests.every((request) => request.method === "GET")).toBe(true);
  } finally {
    fake.restore();
  }
});

test("pagination stays complete when the server cap is lower than the page size", async () => {
  const data = buildDataset();
  const fake = installFakePostgrest(
    { ...otherTables(), orders: data.orders, order_items: data.orderItems, usage_logs: data.usageLogs },
    { cap: 400 },
  );
  try {
    const store = await getFreshStore();
    expect(store.orders).toHaveLength(data.orders.length);
    expect(store.orders.every((order) => order.items.length === data.itemCount.get(order.id))).toBe(true);
    expect(store.usageLogs).toHaveLength(data.usageLogs.length);
  } finally {
    fake.restore();
  }
});

test("a failed page surfaces an error instead of returning a silently short list", async () => {
  const data = buildDataset();
  const fake = installFakePostgrest(
    { ...otherTables(), orders: data.orders, order_items: data.orderItems, usage_logs: data.usageLogs },
    { cap: 1000, failOnOffset: { table: "order_items", offset: 1000 } },
  );
  try {
    await expect(getFreshStore()).rejects.toThrow(/order_items/);
  } finally {
    fake.restore();
  }
});
