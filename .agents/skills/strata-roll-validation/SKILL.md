---
name: strata-roll-validation
description: Independent field-by-field check of a Strata Roll xlsx against the property's raw source CSVs, using the company validation prompt. Use only when the user says "run test workflow" or asks to validate/test a Strata Roll. Never use it to onboard, convert, fix or load data.
---

# strata-roll-validation

Follow the company prompt `prompts/strata_roll_validation_system_prompt 1.md` (note the space before the 1) exactly: its method, its six checks and its tone rules. It is the authority. Do not shorten it or add rules to it. This skill only says where things are and how to behave.

## What you need (ask once if anything is missing)
- The Strata Roll xlsx.
- The property folder. Identify the Owners/Strata Roll, Lot Contacts and Committee CSVs by their headers, and Occupiers if present.
- In `prompts/`: `strata_conversion_system_prompt_v2.9.md`, `strata_compref_system_prompt 2.md`, the company validator (the one `.py` file there, called `validate_strata_roll.py` in the prompt), and the layout sample (the one `.md` file in `examples/`). The sample shows layout only. Never copy its names or values.

## Rules
- Work in a fresh chat. If this chat already contains onboarding work, say so and ask the user to open a new one.
- Read only the inputs above. Do not call SQL, database or onboarding tools. Do not read anything under `output/` from an onboarding run, or any earlier report.
- The property folder data is the source of truth.
- Never change the Roll, the property folder or `prompts/`. If the Roll will not open, repair a copy as Step 0 of the prompt says and report the repair as a finding.

## Method (the prompt's own Step -1)
1. Run the company validator: copy it into the output folder, change only the paths in its CONFIG block, and run the copy.
2. Do yourself whatever the validator does not cover. In particular, scan the whole workbook, every section including Tenant, Nominee and Mortgagee, for literal `undefined`, `null` or `NaN` cells, and for numeric phone, mobile and postcode cells. List the coordinate of every cell you count. Your report totals must equal the scan.
3. Spot-check at least one "clean" result per section against the raw cell, as the prompt requires.

## Report
Write `output/<PLAN>/roll_validation/<PLAN>_findings.md` in exactly the sample's layout and section order, with no other sections:

- Title, the header block (Roll file, Sources, Missing inputs, Lots, fields diffed, mismatches) and a short Method paragraph.
- **1. Communication preference, every lot.** One table row per lot: Fee Notice and Correspondence recipients and delivery code, source to Roll, OK or not. Build it from the validator's per-lot results.
- **2. Mismatches, most significant first.** A "Distinct issues" list, then HIGH, MEDIUM and LOW blocks. Write each mismatch in the prompt's Output format.


- **3. Section-wide numeric-cell-type defects**, then **3b. Literal placeholder cells**, by section with cell coordinates.
- **4. Occupancy cross-check.** If there is no Occupiers CSV, say it was not performed and why.
- **5. Ambiguous / needs human confirmation.** Write "none" if there are none.
- **Summary**, including the per-section row and field counts that check 2 of the prompt requires, and what was not verified.


Put the validator's own report, your scan results and the validator copy in `evidence/`. Create nothing else.

Finish with a short summary in chat: lots checked, mismatches by severity, and what was not verified. Do not propose fixes.
