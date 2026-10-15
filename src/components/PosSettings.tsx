"use client";

import { useState, useTransition } from "react";
import { setPosInventoryFeaturesEnabled } from "@/actions/pos";
import type { StoreData } from "@/lib/types";

export function PosSettings({ store }: { store: StoreData }) {
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  return (
    <div className="min-h-[60vh] space-y-6 bg-neutral-100 p-4 sm:p-6">
      <div>
        <p className="text-xs font-medium uppercase tracking-[0.2em] text-neutral-500">Settings</p>
        <h1 className="mt-1 text-2xl font-semibold">POS Settings</h1>
      </div>

      <section className="flex flex-wrap items-center justify-between gap-4 border border-neutral-200 bg-white p-4 sm:p-5">
        <div>
          <h2 className="font-semibold">POS status</h2>
          <p className="mt-1 text-sm text-neutral-500">Current terminal status and staff member who opened it.</p>
        </div>
        <p
          className={`w-fit rounded-full px-4 py-2 text-sm ${
            store.pos.isOpen
              ? "bg-black text-white"
              : "border border-neutral-300 text-neutral-600"
          }`}
        >
          POS {store.pos.isOpen ? "open" : "closed"}
          {store.pos.openedBy ? ` · ${store.pos.openedBy}` : ""}
        </p>
      </section>

      <section className="flex flex-wrap items-center justify-between gap-4 border border-neutral-200 bg-white p-4 sm:p-5">
        <div>
          <h2 className="font-semibold">POS stock inventory</h2>
          <p className="mt-1 text-sm text-neutral-500">
            Show or hide Stock inventory and Restock in the POS.
          </p>
          {error ? <p role="alert" className="mt-2 text-sm text-red-700">{error}</p> : null}
        </div>
        <button
          type="button"
          disabled={pending}
          aria-pressed={store.pos.inventoryFeaturesEnabled}
          onClick={() => {
            const enabled = !store.pos.inventoryFeaturesEnabled;
            setError(null);
            startTransition(async () => {
              try {
                await setPosInventoryFeaturesEnabled(enabled);
              } catch (cause) {
                setError(cause instanceof Error ? cause.message : "Could not update POS inventory setting.");
              }
            });
          }}
          className={`rounded-full px-4 py-2 text-sm font-medium text-white disabled:opacity-50 ${store.pos.inventoryFeaturesEnabled ? "bg-black" : "bg-neutral-500"}`}
        >
          {pending ? "Saving…" : store.pos.inventoryFeaturesEnabled ? "Visible in POS" : "Hidden in POS"}
        </button>
      </section>
    </div>
  );
}
