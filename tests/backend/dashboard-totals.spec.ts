import { test, expect } from "@playwright/test";
import { ordersOnDay, productStats, sumSales } from "@/lib/analytics";
import type { Order } from "@/lib/types";

// What the Admin dashboard's headline figures mean, and how they relate:
//   Today's Sales  = sum of order.total for non-voided orders on the Manila day
//   Today's Orders = count of those orders
//   Total Sold     = sum of per-product sales built from order.items (revenue
//                    allocated across item lines) with matching unit quantity
// So Total Sold equals Today's Sales only when every order carries its items.
// The process runs in America/Los_Angeles (playwright.backend.config.ts) so
// these also prove the date math does not depend on the device timezone.

const MENU = [{ id: "latte", name: "Latte", category: "Drinks", categoryType: "drinks" }];

function order(id: string, createdAt: string, total: number, items: Order["items"], extra: Partial<Order> = {}): Order {
  return { id, createdAt, baristaName: "Test", items, total, subtotal: total, paymentMethod: "cash", ...extra };
}

const line = (qty: number, price: number, addons: NonNullable<Order["items"][number]["addons"]> = []) =>
  ({ productId: "latte", name: "Latte", qty, price, addons });

const totalSold = (orders: Order[]) => productStats(orders, MENU).reduce((sum, stat) => sum + stat.sales, 0);
const unitsSold = (orders: Order[]) => productStats(orders, MENU).reduce((sum, stat) => sum + stat.qty, 0);

test("Total Sold equals Today's Sales when every order has its items (add-ons and discounts included)", () => {
  const orders = [
    order("a", "2026-10-25T05:10:00.000Z", 125, [line(1, 125)]),
    // add-on with quantity 2 (Espresso x2), as in production ticket 021
    order("b", "2026-10-25T06:00:00.000Z", 255, [line(1, 125, [
      { id: "addon-0", name: "Oat Milk", price: 50, qty: 1 },
      { id: "addon-1", name: "Espresso", price: 40, qty: 2 },
    ])]),
    // order-level discount is allocated across lines, so totals still tie out
    order("c", "2026-10-25T07:00:00.000Z", 180, [line(2, 100)], { subtotal: 200, discount: 20 }),
  ];
  const day = ordersOnDay(orders, new Date("2026-10-25T23:59:59.999+08:00"));
  expect(day).toHaveLength(3);
  expect(sumSales(day)).toBe(560);
  expect(totalSold(day)).toBeCloseTo(560, 6);
  expect(unitsSold(day)).toBe(4);
});

test("orders loaded without items drop out of Total Sold but not out of Today's Sales (the incident symptom)", () => {
  const orders = [
    order("a", "2026-10-25T05:10:00.000Z", 125, [line(1, 125)]),
    order("b", "2026-10-25T14:00:00.000Z", 300, []), // items lost by the 1000-row cap
  ];
  const day = ordersOnDay(orders, new Date("2026-10-25T23:59:59.999+08:00"));
  expect(sumSales(day)).toBe(425); // revenue is read from orders and was never wrong
  expect(totalSold(day)).toBe(125); // item-derived figure is what under-reported
});

test("Manila-day boundaries hold regardless of the device timezone", () => {
  const orders = [
    order("before", "2026-10-24T15:59:59.999Z", 10, [line(1, 10)]), // 23:59:59 on Oct 24 Manila
    order("first", "2026-10-24T16:00:00.000Z", 20, [line(1, 20)]), // 00:00:00 on Oct 25 Manila
    order("last", "2026-10-25T15:59:59.999Z", 30, [line(1, 30)]), // 23:59:59 on Oct 25 Manila
    order("after", "2026-10-25T16:00:00.000Z", 40, [line(1, 40)]), // 00:00:00 on Oct 26 Manila
  ];
  const day = ordersOnDay(orders, new Date("2026-10-25T23:59:59.999+08:00"));
  expect(day.map((o) => o.id)).toEqual(["first", "last"]);
  expect(sumSales(day)).toBe(50);
});

test("voided and soft-deleted orders never count toward Today's Sales or Orders", () => {
  const orders = [
    order("ok", "2026-10-25T05:00:00.000Z", 100, [line(1, 100)]),
    order("void", "2026-10-25T05:05:00.000Z", 255, [line(1, 255)], { voided: true }),
    order("gone", "2026-10-25T05:06:00.000Z", 70, [line(1, 70)], { deletedAt: "2026-10-25T06:00:00.000Z" }),
  ];
  const day = ordersOnDay(orders, new Date("2026-10-25T23:59:59.999+08:00"));
  expect(day.map((o) => o.id)).toEqual(["ok"]);
  expect(sumSales(day)).toBe(100);
});
