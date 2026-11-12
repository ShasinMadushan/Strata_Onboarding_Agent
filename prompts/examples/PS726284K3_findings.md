# Strata Roll validation — PS726284K3

**Roll file:** `Strata Rolls,system/Strata Roll_PS726284K3_Lot_All (1).xlsx`  
**Sources:** `Properties/Plan PS726284K3/Non-Financial Documents/05. Lot Owner details/` — present: Current Lot Owners Report, Committee Members Report, Current Contacts List; **missing: Current Lot Occupiers**.  
**Missing inputs:** Current Lot Occupiers (this tree ships no Current Lot Occupiers CSV for any plan — the occupancy cross-check and lot-physical-address check are not run; see §4)  
**Lots:** 21  |  **Fields diffed (printed expected/actual pairs):** 526  |  **Mismatches:** 29 core + 7 section-wide numeric-format

Method: mechanical field-by-field diff (`batch_validate_ab.py`, a per-plan port of the proven SP 3702 `validate_strata_roll.py` — same helpers, checks and printed expected/actual evidence lines). Every field's expected value is computed from the three source CSVs + the two conversion prompts (`strata_conversion_system_prompt 2.8.md`, `strata_compref_system_prompt 2.md`) and diffed against the extracted Roll cell; full evidence is in `PS726284K3_validation_report.txt`. Severity is a heuristic (`sev_rank`).

The workbook's `xl/styles.xml` carried invalid style-id attributes (`numFmtId="undefined"` etc.) and would not open with `openpyxl` until they were replaced with `0` in a working copy (Step 0; no regex fallback used).

## 1. Communication preference — every lot (highest-priority check)

`recipients` = distinct classified `Contact_Type`(s) the lot's Fee Notice / Correspondence routing rows resolve to (2+ ⇒ the *Both* case ⇒ 2+ rows expected). `Code` = E / P / EP derived from the routing labels (`via email`→E, `to`→P) → the Roll's Delivery Method column. `Notice Details` is diffed as an independent copy of `Correspondence Details` (rule: `Notice_* == Correspondence_*`).

| Lot | Fee Notice: recipients src→Roll | Code | Correspondence: recipients src→Roll | Code | OK? |
|----|----|----|----|----|----|
| G01 | Owner → 1× Warren Salisbury & Thongthip Yansangkat | P→Post | Owner → 1× Warren Salisbury & Thongthip Yansangkat | P→Post | ✓ |
| G02 | Owner → 1× Mr Rakesh Palash & Mrs Tupur Chakrabarty | E→Email | Owner → 1× Mr Rakesh Palash & Mrs Tupur Chakrabarty | E→Email | ✓ |
| G03 | Other1+Owner → 2× Lorenzo Berardino & Katia Prinzio; Lorenzo Berardino & Katia Prinzio | E→Email | Other1+Owner → 2× Lorenzo Berardino & Katia Prinzio; Lorenzo Berardino & Katia Prinzio | E→Email | ✓ |
| G04 | Agent → 1× Hileon Real Estate [Hileon Real Estate]  | E→Email | Owner → 1× Weiquan Xie | E→Email | ✗ field |
| G05 | Agent → 1× Hileon Real Estate [Hileon Real Estate]  | EP→EMAIL & POST | Owner → 1× Weiquan Xie | E→Email | ✗ field |
| G06 | Owner → 1× Chenlu Shang | E→Email | Owner → 1× Chenlu Shang | E→Email | ✓ |
| G07 | Other1+Owner → 2× Bharani Allam & Yogitha Polisetty; Bharani Allam & Yogitha Polisetty | EP→EMAIL & POST | Other1+Owner → 2× Bharani Allam & Yogitha Polisetty; Bharani Allam & Yogitha Polisetty | E→Email | ✓ |
| G08 | Owner → 1× Ms Nijing Li | E→Email | Owner → 1× Ms Nijing Li | E→Email | ✓ |
| 101 | Owner → 1× Aihuan Wu | E→Email | Owner → 1× Aihuan Wu | E→Email | ✓ |
| 102 | Owner → 1× Ngoc Tran | P→Post | Owner → 1× Ngoc Tran | E→Email | ✓ |
| 103 | Owner → 1× Peng Zhu & Dan Xie | P→Post | Other1+Owner → 2× Peng Zhu & Dan Xie; Peng Zhu & Dan Xie | E→Email | ✓ |
| 104 | Owner → 1× Ms Peifen Feng | E→Email | Owner → 1× Ms Peifen Feng | E→Email | ✓ |
| 105 | Owner → 1× Parker Wan | E→Email | Owner → 1× Parker Wan | E→Email | ✓ |
| 106 | Owner → 1× Guowei Hu & Xiaofang Hu | E→Email | Owner → 1× Guowei Hu & Xiaofang Hu | E→Email | ✓ |
| 107 | Owner → 1× Li Zang | EP→EMAIL & POST | Owner → 1× Li Zang | E→Email | ✓ |
| 108 | Owner → 1× Yi Li | EP→EMAIL & POST | Owner → 1× Yi Li | EP→EMAIL & POST | ✓ |
| 201 | Agent → 1× Mandy Lee Real Estate [Mandy Lee Real Estate]  | E→Email | Owner → 1× Peijia Guan | E→Email | ✗ field |
| 202 | Owner → 1× Mr Klaus Klapp & Mrs Patricia Ann Klapp | E→Email | Owner → 1× Mr Klaus Klapp & Mrs Patricia Ann Klapp | E→Email | ✓ |
| 203 | Owner → 1× Luxia Mao | E→Email | Owner → 1× Luxia Mao | E→Email | ✓ |
| 204 | Owner → 1× Edward Phung | P→Post | Owner → 1× Edward Phung | E→Email | ✓ |
| 205 | Owner → 1× Mr Klaus Klapp & Mrs Patricia Ann Klapp | E→Email | Owner → 1× Mr Klaus Klapp & Mrs Patricia Ann Klapp | E→Email | ✓ |

✗ rows are expanded in §2.

## 2. Mismatches — most significant first

**Distinct issues** (the itemised list below repeats some across the Levy / Notice / Correspondence copies):

- **HIGH** · Levy/Notice/Corr · Agent -- Contact Name — lot(s) G04, G05, 201 — _recipient name on the Roll row does not match source; delivery code still checke_
- **MEDIUM** · Agent Details · Contact Name — lot(s) G04, G05, 201 — _business name substituted for contact name, or vice versa_
- **MEDIUM** · Agent Details · Row set — lot(s) ALL — _genuine third-party letting-agent lots differ between source and Roll (incl. sel_
- **MEDIUM** · Tenant Details · Row presence — lot(s) G01, G02, G03, G04, G05, G06, G07, G08, 101, 102, 103, 104 … (21 lots)
- **MEDIUM** · Tenant Details · Row set — lot(s) ALL — _Roll has Tenant rows with no supporting Tenant-classified routing row_

### HIGH

```
[Levy Details] Lot G04 — Agent -- Contact Name
  Expected: one of ['Hileon Real Estate'] (source: routing row for this Fee Notice recipient)
  Found in Strata Roll: Hileon Real Estate [Hileon Real Estate] 
  Likely cause: recipient name on the Roll row does not match source; delivery code still checked positionally
```
```
[Levy Details] Lot G05 — Agent -- Contact Name
  Expected: one of ['Hileon Real Estate', 'Hileon Real Estate'] (source: routing row for this Fee Notice recipient)
  Found in Strata Roll: Hileon Real Estate [Hileon Real Estate] 
  Likely cause: recipient name on the Roll row does not match source; delivery code still checked positionally
```
```
[Levy Details] Lot 201 — Agent -- Contact Name
  Expected: one of ['Mandy Lee Real Estate'] (source: routing row for this Fee Notice recipient)
  Found in Strata Roll: Mandy Lee Real Estate [Mandy Lee Real Estate] 
  Likely cause: recipient name on the Roll row does not match source; delivery code still checked positionally
```

### MEDIUM

```
[Agent Details] Lot ALL — Row set (which lots appear)
  Expected: ['G04', 'G05', '201']
  Found in Strata Roll: ['G01', 'G02', 'G03', 'G04', 'G05', 'G06', 'G07', 'G08', '101', '102', '103', '104', '105', '106', '107', '108', '201', '202', '203', '204', '205']
  Likely cause: genuine third-party letting-agent lots differ between source and Roll (incl. self-managed-placeholder inclusion question)
```
```
[Agent Details] Lot G04 — Contact Name
  Expected: Hileon Real Estate
  Found in Strata Roll: Hileon Real Estate [Hileon Real Estate] 
  Likely cause: business name substituted for contact name, or vice versa
```
```
[Agent Details] Lot G05 — Contact Name
  Expected: Hileon Real Estate
  Found in Strata Roll: Hileon Real Estate [Hileon Real Estate] 
  Likely cause: business name substituted for contact name, or vice versa
```
```
[Agent Details] Lot 201 — Contact Name
  Expected: Mandy Lee Real Estate
  Found in Strata Roll: Mandy Lee Real Estate [Mandy Lee Real Estate] 
  Likely cause: business name substituted for contact name, or vice versa
```
```
[Tenant Details] Lot ALL — Row set
  Expected: no Owners-Report routing row classifies as Tenant -> section expected EMPTY
  Found in Strata Roll: ['G01', 'G02', 'G03', 'G04', 'G05', 'G06', 'G07', 'G08', '101', '102', '103', '104', '105', '106', '107', '108', '201', '202', '203', '204', '205']
  Likely cause: Roll has Tenant rows with no supporting Tenant-classified routing row
```
```
[Tenant Details] Lot G01 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot G02 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot G03 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot G04 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot G05 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot G06 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot G07 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot G08 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot 101 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot 102 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot 103 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot 104 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot 105 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot 106 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot 107 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot 108 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot 201 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot 202 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot 203 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot 204 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```
```
[Tenant Details] Lot 205 — Row presence
  Expected: no Tenant-classified routing row for this lot
  Found in Strata Roll: None
```

## 3. Section-wide numeric-cell-type defect (leading-zero risk)

Australian mobile / phone / postcode values stored as **numeric** cells (not text), so a leading `0` is dropped on display (`0412…` → `412…`). Reported once per section/column (validation check 6), not per cell:

- **Broker Details / Phone 1** — 1 cell(s) should be text, stored as int/float (e.g. row 101 = `1300424627`)
- **Executive Committee / Mobile** — 2 cell(s) should be text, stored as int/float (e.g. row 76 = `448917434`)
- **Insurer Details / Phone 1** — 1 cell(s) should be text, stored as int/float (e.g. row 95 = `94668600`)
- **Insurer Details / PostCode** — 1 cell(s) should be text, stored as int/float (e.g. row 95 = `3001`)
- **Property Details / Post Code** — 1 cell(s) should be text, stored as int/float (e.g. row 3 = `3128`)
- **Strata Managing Agent Details / Phone 1** — 1 cell(s) should be text, stored as int/float (e.g. row 83 = `39183910`)
- **Strata Managing Agent Details / PostCode** — 1 cell(s) should be text, stored as int/float (e.g. row 83 = `3006`)

### 3b. Literal placeholder cells (validation check 4)

- **Agent Details / Address** — literal `undefined`/`null` on lot(s) G01, G02, G03, G06, G07, G08, 101, 102, 103, 104, 105, 106, 107, 108, 202, 203, 204, 205
- **Tenant Details / Address** — literal `undefined`/`null` on lot(s) G01, G02, G03, G04, G05, G06, G07, G08, 101, 102, 103, 104, 105, 106, 107, 108, 201, 202, 203, 204, 205

## 4. Occupancy cross-check (not-owner-occupied ⇒ tenant must be in the Roll)

**Not performed — required input missing.** This tree has no `Current Lot Occupiers` CSV in `Properties/Plan PS726284K3/Non-Financial Documents/05. Lot Owner details/`, so there is no `Owner_Occupier` flag and no occupier-name source. No owner-occupancy status is inferred and no tenant names are fabricated.

What *can* be said from the inputs that are present: the Current Contacts List contains **no `Tenant`-type rows** for any lot, and no Owners-Report routing row classifies as `Tenant`, so the Roll's **Tenant Details** section is *not* empty (it has rows for lot(s) 101, 102, 103, 104, 105, 106, 107, 108, 201, 202, 203, 204, 205, G01, G02, G03, G04, G05, G06, G07, G08 despite no supporting routing row — see the CRITICAL/MEDIUM Tenant Details findings in §2 above) — but the not-owner-occupied ⇒ tenant-present rule itself (which needs the *occupied-by-non-owner* flag, not just the absence of a Tenant classification) cannot be evaluated. Supply `currentLotOccupiers_*.csv` to complete this check.

## 5. Ambiguous / needs human confirmation

- **[Classification] Lot G03** — 'Lorenzo Berardino & Katia Prinzio' name-matches owner in full but address/email diverges -- resolved to non-Owner per rule, verify by hand
- **[Classification] Lot G07** — 'Bharani Allam & Yogitha Polisetty' name-matches owner in full but address/email diverges -- resolved to non-Owner per rule, verify by hand
- **[Classification] Lot 103** — 'Peng Zhu & Dan Xie' name-matches owner in full but address/email diverges -- resolved to non-Owner per rule, verify by hand

## Summary

- Lots checked: **21**
- Fields diffed (printed expected/actual pairs): **526**
- Core field mismatches: **29**  (CRITICAL 0, HIGH 3, MEDIUM 26, LOW 0)
- Section-wide numeric-format defect: **7** section/column(s)
- Occupancy cross-check: **not evaluated** — Current Lot Occupiers input missing
- Ambiguous cases flagged (not scored): **3**
- Sections with no field mismatch: Owner Details, Executive Committee, Unit Entitlements, Notice Details, Correspondence Details; Notice Details == Correspondence Details identity holds
