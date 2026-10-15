"use client";

import { useEffect, useMemo, useState } from "react";
import { drinkStyleLabelList, formatMoney, normalizeMenuAddons, normalizeMenuTypes } from "@/lib/menu";
import type { MenuItem } from "@/lib/types";

type DrinksMenuProps = {
  items: MenuItem[];
  categories?: string[];
};

function normalizeCat(name: string) {
  const trimmed = name.trim() || "Other";
  return trimmed.replace(/^non[\s-]*coffee$/i, "Non-Coffee");
}

function orderedCategories(items: MenuItem[], preferred: string[]) {
  const present = new Map<string, string>();
  for (const item of items) {
    const category = normalizeCat(item.category);
    const key = category.toLowerCase();
    if (!present.has(key)) present.set(key, category);
  }

  const ordered: string[] = [];
  const seen = new Set<string>();

  for (const name of preferred) {
    const key = normalizeCat(name).toLowerCase();
    const category = present.get(key);
    if (!category || seen.has(key)) continue;
    seen.add(key);
    ordered.push(category);
  }

  for (const [key, category] of present) {
    if (seen.has(key)) continue;
    seen.add(key);
    ordered.push(category);
  }

  return ordered;
}

export function DrinksMenu({ items, categories = [] }: DrinksMenuProps) {
  const [section, setSection] = useState("All");

  const categoryNames = useMemo(
    () => orderedCategories(items, categories),
    [items, categories],
  );

  useEffect(() => {
    if (section !== "All" && !categoryNames.some((name) => name === section)) {
      setSection("All");
    }
  }, [section, categoryNames]);

  const grouped = useMemo(() => {
    const map = new Map<string, MenuItem[]>();
    for (const item of items) {
      const category = normalizeCat(item.category);
      const list = map.get(category) ?? [];
      list.push(item);
      map.set(category, list);
    }
    return map;
  }, [items]);

  const visible = section === "All" ? categoryNames : categoryNames.filter((name) => name === section);

  return (
    <>
      <div className="sticky top-0 z-10 mb-12 border-b border-white/10 bg-black/90 py-4 backdrop-blur-md">
        <div className="flex flex-wrap gap-2">
          {["All", ...categoryNames].map((name) => {
            const active = section === name;
            return (
              <button
                key={name}
                type="button"
                onClick={() => {
                  setSection(name);
                  window.scrollTo({ top: 0, behavior: "smooth" });
                }}
                className={`rounded-full border px-4 py-2 text-[10px] font-semibold uppercase tracking-[0.18em] transition sm:px-5 sm:text-xs ${
                  active
                    ? "border-white bg-white text-black"
                    : "border-white/25 text-white/80 hover:border-white hover:bg-white hover:text-black"
                }`}
              >
                {name}
              </button>
            );
          })}
        </div>
      </div>

      <div className="space-y-16">
        {visible.map((category) => {
          const drinks = grouped.get(category) ?? [];
          if (drinks.length === 0) return null;
          return (
            <div key={category}>
              <div className="mb-6 flex items-center gap-4">
                <h2 className="text-xs font-semibold uppercase tracking-[0.3em] text-neutral-400">
                  {category}
                </h2>
                <div className="h-px flex-1 bg-white/10" />
              </div>

              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {drinks.map((item) => (
                  <div
                    key={item.id}
                    className="group relative flex flex-col justify-between rounded-2xl border border-white/10 bg-neutral-900/50 p-5 transition duration-300 hover:border-white/30 hover:bg-neutral-900"
                  >
                    <h3 className="font-medium tracking-wide text-white text-base">
                      {item.name}
                    </h3>
                    {normalizeMenuAddons(item).length > 0 ? (
                      <div className="mt-4 border-t border-white/5 pt-3">
                        <p className="text-[10px] uppercase tracking-[0.2em] text-neutral-500">
                          Add-ons
                        </p>
                        <ul className="mt-2 space-y-1.5">
                          {normalizeMenuAddons(item).map((addon) => (
                            <li
                              key={addon.id}
                              className="flex items-center justify-between gap-3 text-xs text-neutral-300"
                            >
                              <span>{addon.name}</span>
                              <span className="shrink-0 text-neutral-400">
                                +{formatMoney(addon.price)}
                              </span>
                            </li>
                          ))}
                        </ul>
                      </div>
                    ) : null}
                    {drinkStyleLabelList(item) !== "—" ? (
                      <p className="mt-2 text-[10px] uppercase tracking-[0.2em] text-neutral-500">
                        {drinkStyleLabelList(item)}
                      </p>
                    ) : null}
                    {normalizeMenuTypes(item).length > 0 ? (
                      <div className="mt-4 border-t border-white/5 pt-3">
                        <p className="text-[10px] uppercase tracking-[0.2em] text-neutral-500">
                          Types
                        </p>
                        <p className="mt-2 text-xs text-neutral-300">
                          {normalizeMenuTypes(item).join(", ")}
                        </p>
                      </div>
                    ) : null}
                    <div className="mt-6 flex items-center justify-between border-t border-white/5 pt-4">
                      <span className="text-[10px] uppercase tracking-[0.2em] text-neutral-500">
                        Available
                      </span>
                      <span className="font-semibold text-neutral-200">
                        {formatMoney(item.price)}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          );
        })}
      </div>
    </>
  );
}
