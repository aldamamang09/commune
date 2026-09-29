import { PosClient } from "@/components/PosClient";
import { StaffLogin } from "@/components/StaffLogin";
import { getSession } from "@/lib/auth";
import { getStore } from "@/lib/store";
import { canUsePos } from "@/lib/users";
import { openBaristaShifts } from "@/lib/staff-sessions";

export const dynamic = "force-dynamic";

export default async function PosPage() {
  const session = await getSession();
  if (!session || !canUsePos(session.role)) {
    return <StaffLogin role="cashier" />;
  }

  const store = await getStore();
  const clockedInBaristas = openBaristaShifts(store.loginActivity ?? []).map((s) => ({
    id: s.userId,
    name: s.name,
    username: s.username,
  }));

  return (
    <main className="min-h-screen bg-neutral-900 text-white">
      <PosClient
        session={session}
        pos={store.pos}
        menu={store.menu}
        categories={store.categories}
        promotions={store.promotions}
        orders={store.orders}
        clockedInBaristas={clockedInBaristas}
        printJobs={store.printJobs ?? []}
        voidRequests={store.voidRequests ?? []}
        inventoryStore={store}
      />
    </main>
  );
}
