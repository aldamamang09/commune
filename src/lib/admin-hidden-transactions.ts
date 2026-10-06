import { useSyncExternalStore } from "react";

export const ADMIN_HIDDEN_TRANSACTIONS_KEY = "admin-hidden-transactions";

const ADMIN_HIDDEN_TRANSACTIONS_EVENT = "admin-hidden-transactions-change";
const EMPTY_HIDDEN_TRANSACTION_IDS: string[] = [];
let cachedStorageValue: string | null = null;
let cachedHiddenIds = EMPTY_HIDDEN_TRANSACTION_IDS;

function getSnapshot(): string[] {
  const saved =
    window.localStorage.getItem(ADMIN_HIDDEN_TRANSACTIONS_KEY) ?? "";
  if (saved === cachedStorageValue) return cachedHiddenIds;
  if (!saved) {
    cachedStorageValue = saved;
    cachedHiddenIds = EMPTY_HIDDEN_TRANSACTION_IDS;
    return cachedHiddenIds;
  }

  const parsed: unknown = JSON.parse(saved);
  if (!Array.isArray(parsed) || !parsed.every((id) => typeof id === "string")) {
    throw new Error("Saved hidden Admin transactions have an invalid format.");
  }
  cachedStorageValue = saved;
  cachedHiddenIds = parsed;
  return cachedHiddenIds;
}

function getServerSnapshot(): string[] {
  return EMPTY_HIDDEN_TRANSACTION_IDS;
}

export function useHiddenAdminTransactionIds(): string[] {
  return useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);
}

export function hideAdminTransaction(id: string): string[] {
  const nextIds = [...new Set([...getSnapshot(), id])];
  window.localStorage.setItem(
    ADMIN_HIDDEN_TRANSACTIONS_KEY,
    JSON.stringify(nextIds),
  );
  cachedStorageValue = null;
  window.dispatchEvent(new Event(ADMIN_HIDDEN_TRANSACTIONS_EVENT));
  return nextIds;
}

function subscribe(onChange: () => void): () => void {
  const handleStorage = (event: StorageEvent) => {
    if (event.key === ADMIN_HIDDEN_TRANSACTIONS_KEY || event.key === null) {
      cachedStorageValue = null;
      onChange();
    }
  };

  window.addEventListener(ADMIN_HIDDEN_TRANSACTIONS_EVENT, onChange);
  window.addEventListener("storage", handleStorage);
  return () => {
    window.removeEventListener(ADMIN_HIDDEN_TRANSACTIONS_EVENT, onChange);
    window.removeEventListener("storage", handleStorage);
  };
}
