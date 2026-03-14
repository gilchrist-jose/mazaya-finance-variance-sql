# Finance Expense Variance Reporting — SQL Portfolio Project

**Industry:** Retail / E-Commerce  
**Database:** PostgreSQL  
**Scope:** Full-year (Jan–Dec 2024) actuals vs budget analysis across departments and GL accounts

---

## Overview

This project models a corporate finance variance reporting workflow for **Mazaya Retail Group**, a Dubai-based multi-department retailer. The analysis covers budget vs actuals across four business units, seven expense accounts, and three revenue accounts producing department level variance reports, threshold breach detection, and an overspend leaderboard.

This work goes through finance analytics in ERP adjacent environments where GL data is extracted into a relational database for reporting a common pattern in SAP, Oracle, and similar enterprise finance systems.

---

## Business Questions Answered

- How did each department perform against budget across every GL account and month?
- Which accounts breached the acceptable variance threshold and require escalation?
- Which months triggered the breach and when did the overspend begin?
- Which departments are the worst offenders by total expense overspend?

---

## Schema Design

Four normalised tables. Reference data (departments, GL accounts) is stored once and referenced by ID eliminating redundancy.

```
departments        gl_accounts
───────────        ───────────
dept_id (PK)       account_id (PK)
dept_name          account_code
                   account_name
                   account_type (EXPENSE / REVENUE)
      │                   │
      └─────────┬──────────┘
                │
         budget / actuals
         ───────────────
         dept_id    (FK → departments)
         account_id (FK → gl_accounts)
         month      (DATE — first of month)
         budget_amount / actual_amount
```

**Grain:** `dept_id + account_id + month` — one row per department, account, and period. All JOINs between budget and actuals enforce this three-column grain to prevent cartesian products.

---

## Project Structure

```
├── scripts/
│   ├── 01_schema_and_seed_data.sql     — DDL and full-year seed data
│   ├── 02_core_variance_report.sql     — Month-level and annual variance report
│   ├── 03_threshold_flagging.sql       — Breach detection and monthly drill-down
│   └── 04_department_ranking.sql       — Overspend leaderboard with window functions
└── README.md
```

---

## Scripts

### 01 — Schema & Seed Data
Creates the four-table normalised schema and populates a full year of budget and actuals data across four departments.

### 02 — Core Variance Report
Joins budget to actuals on all three grain columns and calculates variance amount, variance percentage, and a FAVORABLE / UNFAVORABLE classification for each department + account + month combination. Classification logic accounts for account type — a revenue account beating budget is FAVORABLE; the same positive variance on an expense account is UNFAVORABLE. Produces both a month-level detail view and a full-year annual summary.

**Key SQL:** Multi-table JOIN on composite grain, GROUP BY with multiple aggregations, CASE WHEN with account-type-aware business logic, NULLIF for division-by-zero protection.

### 03 — Threshold Flagging & Breach Detection
Filters the annual summary to surface only department + account combinations where the variance exceeds a 5% threshold — the point at which variances are considered material and require a management response. Unfavorable variances are banded into WARNING (5–10%) and CRITICAL (>10%) severity tiers. A companion month-by-month drill-down identifies exactly when each breach began.

**Key SQL:** HAVING vs WHERE distinction, aggregate filtering, severity banding with CASE WHEN, account-type-aware threshold direction.

### 04 — Department Overspend Leaderboard
Ranks departments from highest to lowest total expense overspend using window functions. A second ranking layer surfaces which accounts within each department are driving the overspend — using PARTITION BY to reset the rank counter per department independently.

**Key SQL:** DENSE_RANK() with OVER(), PARTITION BY for within-group ranking, subquery in FROM clause, GREATEST() for display floor logic.

---

## SQL Concepts Demonstrated

| Concept | Where Used |
|---|---|
| Multi-table JOIN on composite key | All scripts |
| GROUP BY with multiple aggregations | Scripts 02, 03, 04 |
| CASE WHEN with business logic | Scripts 02, 03, 04 |
| NULLIF for division-by-zero protection | Scripts 02, 03, 04 |
| HAVING vs WHERE | Script 03 |
| DENSE_RANK() window function | Script 04 |
| PARTITION BY for within-group ranking | Script 04 |
| Subquery in FROM clause | Script 04 |
| GREATEST() for value flooring | Script 04 |

---

## Key Design Decisions

**Why are budget and actuals stored as separate tables?**  
Separate tables make it structurally impossible to mix budget and actual rows in an aggregation. They also mirror how ERP systems like SAP and Oracle export GL data — as distinct budget and actuals datasets.

**Why is month stored as DATE rather than integer?**  
Storing month as the first day of each period keeps it compatible with PostgreSQL date functions (`date_trunc`, `TO_CHAR`, interval arithmetic) without requiring type casting at query time.

**Why is account_code stored as VARCHAR?**  
Account codes are identifiers, not quantities. VARCHAR preserves formatting flexibility — leading zeros, alphanumeric suffixes — and correctly signals to any reader of the schema that this column is never used in arithmetic.

**Why DENSE_RANK() over RANK()?**  
In a business reporting context, ranking gaps (1, 1, 3) create unnecessary confusion for non-technical stakeholders. DENSE_RANK() produces a clean continuous sequence (1, 1, 2) which reads more naturally in an executive report.
