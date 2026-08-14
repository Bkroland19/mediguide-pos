import { describe, expect, it } from "vitest";

import { normalizeDashboardBaseUrl } from "./config";

describe("normalizeDashboardBaseUrl", () => {
  it("adds the dashboard base path to a public origin", () => {
    expect(normalizeDashboardBaseUrl("https://mediguide.health.go.ug")).toBe(
      "https://mediguide.health.go.ug/admin",
    );
  });

  it("does not duplicate an existing dashboard base path", () => {
    expect(
      normalizeDashboardBaseUrl("https://mediguide.health.go.ug/admin/"),
    ).toBe("https://mediguide.health.go.ug/admin");
  });
});
