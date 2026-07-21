# LandingZoneLite Validation Report

Generated: 2026-07-18 09:42:11 (local)

Summary: **9 passed**, **0 failed**, **2 skipped**

| Component | Target | Status | Detail |
|---|---|---|---|
| Resource Group (mgmt) | rg-lzlite-mgmt-eastus | PASS | Exists with all required tags |
| Resource Group (data) | rg-lzlite-data-eastus | PASS | Exists with all required tags |
| Resource Group (network) | rg-lzlite-network-eastus | SKIPPED | -IncludeNetwork not requested |
| Storage Account | stlzlitekqzmta | PASS | Secure transfer on, TLS1.2 minimum, public access disabled |
| Key Vault | kv-lzlite-kqzmta | PASS | Exists with RBAC authorization enabled |
| Policy Assignment | inherit-tag-lzlite | PASS | Assigned at scope /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-lzlite-mgmt-eastus |
| Consumption Budget | budget-lzlite-monthly | PASS | Amount: 5 |
| Virtual Network | vnet-lzlite-spoke-eastus | SKIPPED | -IncludeNetwork not requested |

Overall result: **PASS** — no failing checks.

---

## Example: report from a run with `-IncludeNetwork`

Generated: 2026-07-18 10:05:47 (local)

Summary: **11 passed**, **0 failed**, **0 skipped**

| Component | Target | Status | Detail |
|---|---|---|---|
| Resource Group (mgmt) | rg-lzlite-mgmt-eastus | PASS | Exists with all required tags |
| Resource Group (data) | rg-lzlite-data-eastus | PASS | Exists with all required tags |
| Resource Group (network) | rg-lzlite-network-eastus | PASS | Exists with all required tags |
| Storage Account | stlzlitekqzmta | PASS | Secure transfer on, TLS1.2 minimum, public access disabled |
| Key Vault | kv-lzlite-kqzmta | PASS | Exists with RBAC authorization enabled |
| Policy Assignment | inherit-tag-lzlite | PASS | Assigned at scope /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-lzlite-mgmt-eastus |
| Consumption Budget | budget-lzlite-monthly | PASS | Amount: 5 |
| Virtual Network | vnet-lzlite-spoke-eastus | PASS | Address space: 10.30.0.0/16 |

Overall result: **PASS** — no failing checks.

---

## Example: report with a failing check (before fixing storage account public access)

Generated: 2026-07-15 21:18:03 (local)

Summary: **8 passed**, **1 failed**, **2 skipped**

| Component | Target | Status | Detail |
|---|---|---|---|
| Resource Group (mgmt) | rg-lzlite-mgmt-eastus | PASS | Exists with all required tags |
| Resource Group (data) | rg-lzlite-data-eastus | PASS | Exists with all required tags |
| Resource Group (network) | rg-lzlite-network-eastus | SKIPPED | -IncludeNetwork not requested |
| Storage Account | stlzlitekqzmta | FAIL | public blob access enabled |
| Key Vault | kv-lzlite-kqzmta | PASS | Exists with RBAC authorization enabled |
| Policy Assignment | inherit-tag-lzlite | PASS | Assigned at scope /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-lzlite-mgmt-eastus |
| Consumption Budget | budget-lzlite-monthly | PASS | Amount: 5 |
| Virtual Network | vnet-lzlite-spoke-eastus | SKIPPED | -IncludeNetwork not requested |

Overall result: **FAIL** — one or more checks failed. See table above.

Console exit code in this scenario: `1` (suitable for failing a CI/CD pipeline step).
