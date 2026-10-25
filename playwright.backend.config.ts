import { defineConfig } from "@playwright/test";

// Backend/unit specs: no browser, no dev server, no network. They run with a
// non-Manila process timezone on purpose - dashboard date math must not
// depend on the device clock (the café's tablets and Vercel run in other zones).
process.env.TZ = "America/Los_Angeles";

export default defineConfig({
  testDir: "./tests/backend",
  testMatch: /.*\.spec\.ts/,
  fullyParallel: false,
  workers: 1,
  reporter: [["list"]],
  timeout: 30_000,
});
