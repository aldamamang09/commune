import bcrypt from "bcryptjs";
import { NextRequest, NextResponse } from "next/server";
import { ingredientsForOrderLine, roundQty } from "@/lib/inventory";
import { normalizeMenuAddons, normalizeMenuStyles } from "@/lib/menu";
import { parsePayment } from "@/lib/payments";
import {
  createOrderAtomic,
  createRestockAtomic,
  deleteInventoryItemRecord,
  deleteOrderAtomic,
  deleteRestockAtomic,
  editRestockAtomic,
  getFreshStore,
  insertLoginActivityRecord,
  insertVoidRequestRecord,
  updateStore,
  voidOrderAtomic,
} from "@/lib/store";
import type { InventoryItem, Order, OrderItem, VoidRequest } from "@/lib/types";
import { parseRole } from "@/lib/users";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Requested-With",
  "Cache-Control": "no-store, no-cache, must-revalidate",
};

export async function OPTIONS() {
  return new NextResponse(null, { status: 204, headers: corsHeaders });
}

export async function GET() {
  try {
    const store = await getFreshStore();
    return NextResponse.json(
      {
        ok: true,
        timestamp: new Date().toISOString(),
        pos: store.pos,
        menu: store.menu.map((item) => ({
          ...item,
          styles: normalizeMenuStyles(item),
          addons: normalizeMenuAddons(item),
        })),
        categories: store.categories,
        promotions: store.promotions,
        inventory: store.inventory,
        orders: store.orders,
        restocks: store.restocks,
        usageLogs: store.usageLogs,
        recipes: store.recipes,
        recipeCostings: store.recipeCostings,
        costings: store.costings,
        voidRequests: store.voidRequests,
        loginActivity: store.loginActivity,
        users: store.users.map((u) => {
          const resolvedRole = parseRole(String(u.title ?? ""), u.role);
          return {
            id: u.id,
            username: u.username,
            password: u.password,
            name: u.name,
            role: resolvedRole,
            title:
              u.title ||
              (resolvedRole === "admin"
                ? "Owner"
                : resolvedRole === "manager"
                  ? "Manager"
                  : resolvedRole === "cashier"
                    ? "Cashier"
                    : "Barista"),
          };
        }),
      },
      { headers: corsHeaders },
    );
  } catch (error) {
    return NextResponse.json(
      {
        ok: false,
        error: error instanceof Error ? error.message : "Failed to load centralized store",
      },
      { status: 500, headers: corsHeaders },
    );
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const action = String(body?.action ?? "").trim();

    if (action === "auth") {
      const username = String(body.username ?? "").trim().toLowerCase();
      const password = String(body.password ?? "");
      if (!username || !password) {
        return NextResponse.json(
          { ok: false, error: "Enter username and password." },
          { status: 400, headers: corsHeaders },
        );
      }

      const store = await getFreshStore();
      const user = store.users.find(
        (u) =>
          u.username.trim().toLowerCase() === username ||
          u.name.trim().toLowerCase() === username,
      );
      if (!user || !user.password) {
        return NextResponse.json(
          { ok: false, error: "Invalid staff credentials." },
          { status: 401, headers: corsHeaders },
        );
      }

      const validPassword = user.password.startsWith("$2")
        ? await bcrypt.compare(password, user.password)
        : user.password === password || user.password.trim() === password.trim();

      if (!validPassword) {
        return NextResponse.json(
          { ok: false, error: "Invalid staff credentials." },
          { status: 401, headers: corsHeaders },
        );
      }

      const resolvedRole = parseRole(String(user.title ?? ""), user.role);
      return NextResponse.json(
        {
          ok: true,
          user: {
            id: user.id,
            username: user.username,
            name: user.name,
            role: resolvedRole,
            title: user.title || (resolvedRole === "admin" ? "Owner" : resolvedRole === "manager" ? "Manager" : resolvedRole === "cashier" ? "Cashier" : "Barista"),
          },
        },
        { headers: corsHeaders },
      );
    }

    if (action === "create_order") {
      const rawOrder = body.order ?? {};
      const store = await getFreshStore();
      const existingOrder = store.orders.find((o) => o.id === rawOrder.id);
      if (existingOrder) {
        return NextResponse.json(
          { ok: true, ticketNo: existingOrder.ticketNo ?? rawOrder.ticketNo ?? "", order: existingOrder },
          { headers: corsHeaders },
        );
      }

      const orderItems: OrderItem[] = Array.isArray(rawOrder.items)
        ? rawOrder.items.map((item: Record<string, unknown>) => ({
            productId: String(item.productId ?? ""),
            name: String(item.name ?? ""),
            qty: Math.max(1, Number(item.qty) || 1),
            price: Number(item.price) || 0,
            style: item.style === "hot" || item.style === "iced" ? item.style : undefined,
            addons: Array.isArray(item.addons)
              ? item.addons.map((a: Record<string, unknown>) => ({
                  id: typeof a.id === "string" ? a.id : undefined,
                  name: String(a.name ?? ""),
                  price: Number(a.price) || 0,
                  qty: Math.max(1, Number(a.qty) || 1),
                  inventoryItemId: typeof a.inventoryItemId === "string" ? a.inventoryItemId : undefined,
                  usageAmount: a.usageAmount != null ? Number(a.usageAmount) : undefined,
                  usageUnit: typeof a.usageUnit === "string" ? a.usageUnit : undefined,
                }))
              : undefined,
            category: typeof item.category === "string" ? item.category : undefined,
          }))
        : [];

      const order: Order = {
        id: String(rawOrder.id || `ord-${Date.now()}`),
        createdAt: String(rawOrder.createdAt || new Date().toISOString()),
        baristaName: String(rawOrder.baristaName || "Barista"),
        items: orderItems,
        subtotal: Number(rawOrder.subtotal) || 0,
        discount: Number(rawOrder.discount) || 0,
        promoLabel: typeof rawOrder.promoLabel === "string" ? rawOrder.promoLabel : undefined,
        total: Number(rawOrder.total) || 0,
        paymentMethod: parsePayment(rawOrder.paymentMethod),
        ticketNo: typeof rawOrder.ticketNo === "string" ? rawOrder.ticketNo : "",
        paid: Number(rawOrder.paid ?? rawOrder.total) || 0,
        change: Number(rawOrder.change) || 0,
        voided: Boolean(rawOrder.voided),
        voidReason: typeof rawOrder.voidReason === "string" ? rawOrder.voidReason : undefined,
      };

      // Calculate deductions using the exact Admin recipe/costing/addon configuration
      const deductions: {
        inventoryItemId: string;
        itemName: string;
        amount: number;
        unit: string;
        orderItemId?: string;
      }[] = [];

      for (const line of order.items) {
        const ingredients = ingredientsForOrderLine(store, line);
        for (const ingredient of ingredients) {
          const matchedStock = store.inventory.find(
            (inv) =>
              (ingredient.inventoryItemId && inv.id === ingredient.inventoryItemId) ||
              inv.name.trim().toLowerCase() === ingredient.name.trim().toLowerCase(),
          );
          if (!matchedStock) continue;
          const usedAmount = roundQty(Number(ingredient.amount) * line.qty);
          if (usedAmount <= 0) continue;
          deductions.push({
            inventoryItemId: matchedStock.id,
            itemName: matchedStock.name,
            amount: usedAmount,
            unit: ingredient.unit || matchedStock.unit || "pcs",
            orderItemId: line.productId,
          });
        }
      }

      const result = await createOrderAtomic({
        order,
        deductions,
      });

      if (!result.ok) {
        return NextResponse.json(
          { ok: false, error: result.error },
          { status: 400, headers: corsHeaders },
        );
      }

      order.ticketNo = result.ticketNo || order.ticketNo;
      return NextResponse.json(
        { ok: true, ticketNo: order.ticketNo, order },
        { headers: corsHeaders },
      );
    }

    if (action === "void_order") {
      const orderId = String(body.orderId ?? "").trim();
      const reason = String(body.reason ?? "Voided from POS").trim();
      const voidedBy = typeof body.voidedBy === "string" ? body.voidedBy : null;
      const managerUsername = typeof body.managerUsername === "string" ? body.managerUsername.trim().toLowerCase() : "";
      const managerPassword = typeof body.managerPassword === "string" ? body.managerPassword : "";

      if (managerUsername && managerPassword) {
        const store = await getFreshStore();
        const manager = store.users.find((u) => u.username.trim().toLowerCase() === managerUsername);
        const role = manager ? parseRole(String(manager.title ?? manager.role ?? "barista")) : "barista";
        if (!manager || (role !== "manager" && role !== "admin")) {
          return NextResponse.json(
            { ok: false, error: "Manager or Admin credentials required to void an order." },
            { status: 403, headers: corsHeaders },
          );
        }
        const valid = manager.password.startsWith("$2")
          ? await bcrypt.compare(managerPassword, manager.password)
          : manager.password === managerPassword;
        if (!valid) {
          return NextResponse.json(
            { ok: false, error: "Invalid manager password." },
            { status: 403, headers: corsHeaders },
          );
        }
      }

      const res = await voidOrderAtomic(orderId, reason, voidedBy);
      return NextResponse.json(res, { status: res.ok ? 200 : 400, headers: corsHeaders });
    }

    if (action === "delete_order") {
      const orderId = String(body.orderId ?? "").trim();
      if (!orderId) {
        return NextResponse.json({ ok: false, error: "Missing orderId" }, { status: 400, headers: corsHeaders });
      }
      await deleteOrderAtomic(orderId);
      return NextResponse.json({ ok: true }, { headers: corsHeaders });
    }

    if (action === "create_restock") {
      const record = body.restock ?? body;
      const id = String(record.id || `rst-${Date.now()}`);
      const inventoryItemId = record.inventoryItemId ? String(record.inventoryItemId) : null;
      const itemNameSnapshot = String(record.itemName ?? record.itemNameSnapshot ?? "");
      const quantityAdded = Number(record.quantityAdded) || 0;
      const createdAt = String(record.date ?? record.createdAt ?? new Date().toISOString());
      const purchaseQty = record.purchaseQty != null ? Number(record.purchaseQty) : null;
      const purchaseUnit = typeof record.purchaseUnit === "string" ? record.purchaseUnit : null;

      const store = await getFreshStore();
      if (!store.restocks.some((r) => r.id === id)) {
        await createRestockAtomic({
          id,
          inventoryItemId,
          itemNameSnapshot,
          quantityAdded,
          createdAt,
          purchaseQty,
          purchaseUnit,
        });
      }
      return NextResponse.json({ ok: true, id }, { headers: corsHeaders });
    }

    if (action === "edit_restock") {
      await editRestockAtomic({
        id: String(body.id),
        oldInventoryItemId: body.oldInventoryItemId ?? null,
        oldQuantity: Number(body.oldQuantity) || 0,
        newInventoryItemId: body.newInventoryItemId ?? null,
        newItemNameSnapshot: String(body.newItemNameSnapshot ?? ""),
        newQuantity: Number(body.newQuantity) || 0,
        newCreatedAt: String(body.newCreatedAt ?? new Date().toISOString()),
        newPurchaseQty: body.newPurchaseQty != null ? Number(body.newPurchaseQty) : null,
        newPurchaseUnit: body.newPurchaseUnit ?? null,
      });
      return NextResponse.json({ ok: true }, { headers: corsHeaders });
    }

    if (action === "delete_restock") {
      const id = String(body.id ?? "").trim();
      if (!id) {
        return NextResponse.json({ ok: false, error: "Missing restock id" }, { status: 400, headers: corsHeaders });
      }
      await deleteRestockAtomic({ id });
      return NextResponse.json({ ok: true }, { headers: corsHeaders });
    }

    if (action === "upsert_inventory_item") {
      const raw = body.item ?? {};
      const item: InventoryItem = {
        id: String(raw.id || `stock-${Date.now()}`),
        name: String(raw.name ?? "").trim(),
        unit: String(raw.unit || "pcs").trim(),
        cost: Number(raw.cost) || 0,
        stock: Number(raw.stock) || 0,
        maxStock: Number(raw.maxStock ?? raw.stock) || 0,
        openingStock: raw.openingStock != null ? Number(raw.openingStock) : undefined,
        purchaseUnitSize: raw.purchaseUnitSize != null ? Number(raw.purchaseUnitSize) : undefined,
        cupUsageAmount: raw.cupUsageAmount != null ? Number(raw.cupUsageAmount) : undefined,
        cupsMake: raw.cupsMake != null ? Number(raw.cupsMake) : undefined,
      };
      if (!item.name) {
        return NextResponse.json({ ok: false, error: "Item name is required" }, { status: 400, headers: corsHeaders });
      }
      await updateStore((store) => {
        const idx = store.inventory.findIndex((i) => i.id === item.id);
        if (idx >= 0) {
          store.inventory[idx] = item;
        } else {
          store.inventory.push(item);
        }
      });
      return NextResponse.json({ ok: true, item }, { headers: corsHeaders });
    }

    if (action === "delete_inventory_item") {
      const id = String(body.id ?? "").trim();
      if (!id) {
        return NextResponse.json({ ok: false, error: "Missing inventory item id" }, { status: 400, headers: corsHeaders });
      }
      const res = await deleteInventoryItemRecord(id);
      if ("error" in res) {
        return NextResponse.json({ ok: false, error: res.error }, { status: 400, headers: corsHeaders });
      }
      return NextResponse.json({ ok: true }, { headers: corsHeaders });
    }

    if (action === "create_void_request") {
      const raw = body.request ?? body;
      const reqRecord: VoidRequest = {
        id: String(raw.id || `vr-${Date.now()}`),
        requestedAt: String(raw.requestedAt || new Date().toISOString()),
        requestedById: String(raw.requestedById || "cashier"),
        requestedByName: String(raw.requestedByName || "Cashier"),
        reason: String(raw.reason || "Void requested"),
        status: "pending",
        orderId: typeof raw.orderId === "string" ? raw.orderId : undefined,
        items: Array.isArray(raw.items) ? raw.items : [],
        subtotal: Number(raw.subtotal) || 0,
        discount: Number(raw.discount) || 0,
        promoLabel: typeof raw.promoLabel === "string" ? raw.promoLabel : undefined,
        total: Number(raw.total) || 0,
        paymentMethod: parsePayment(raw.paymentMethod),
      };
      await insertVoidRequestRecord(reqRecord);
      return NextResponse.json({ ok: true, request: reqRecord }, { headers: corsHeaders });
    }

    if (action === "login_activity") {
      const raw = body.activity ?? body;
      const entry = {
        id: String(raw.id || `log-${Date.now()}`),
        userId: String(raw.userId || "staff"),
        username: String(raw.username || "staff"),
        name: String(raw.name || "Staff"),
        role: parseRole(String(raw.role || "barista")),
        type: (raw.type === "logout" ? "logout" : "login") as "login" | "logout",
        at: String(raw.at || new Date().toISOString()),
      };
      await insertLoginActivityRecord(entry);
      if (entry.type === "login") {
        await updateStore((store) => {
          store.pos.isOpen = true;
          store.pos.openedBy = entry.name;
          store.pos.openedAt = entry.at;
        });
      }
      return NextResponse.json({ ok: true }, { headers: corsHeaders });
    }

    return NextResponse.json(
      { ok: false, error: `Unknown sync action: ${action}` },
      { status: 400, headers: corsHeaders },
    );
  } catch (error) {
    return NextResponse.json(
      {
        ok: false,
        error: error instanceof Error ? error.message : "Sync operation failed",
      },
      { status: 500, headers: corsHeaders },
    );
  }
}
