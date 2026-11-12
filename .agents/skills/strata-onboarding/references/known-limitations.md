# Known limitations

- Property linking: no team-provided add-property procedure exists. In this project always resolve properties with F_SNG_Properties_L3_CORE(69). The user's managing_scope means ManagingCompanyCode (ABOVEOCM), not a UserID override. If the property does not resolve under scope 69, stop and ask; never alter stock procedure parameters or logic to work around scope. A user-supplied linking script is only a temporary local-development utility, separately reviewed and approved.

- ABOVEOCM downstream visibility / LotCount (confirmed 2026-09-22, V2_SNG_ERP_DEV): SupplierID 1 exists and has its company linkage, but F_SNG_UserAccounts_L3(NULL) contains no ABOVEOCM row. F_SNG_Suppliers_L2X(69) still requires company-code membership even under scope 69, so it excludes that supplier. Consequently F_SNG_ManagingCompanies_L3(69) and F_SNG_Properties_L3(69) omit the property although F_SNG_Properties_L3_CORE(69) resolves it. The stock P_SNG_MANUALLOT_AddAddresses_DL consequently calculates LotCount=0. With explicit per-run confirmation, run stock imports unchanged and accept this temporary count. After core imports finish, prepare a separate, explicitly approved post-hoc UPDATE of T_SNG_Properties.LotCount for the target PropertyID/PlanNumber only, using the verified active-lot count from T_SNG_Lots and reconciling it to imported lot coverage (31 for PS732663R/property 1). Verify the corrected count afterward. Do not modify stock procedures, fabricate account records, or silently bypass this issue. This fixes stored LotCount only; it does not repair L3 visibility or the separate owner preflight. User authorized this method for the current PS732663R run; each concrete SQL write still needs its individual approval.
- Distinct contacts: ImportOwners re-tags the owner's contact. SM_CommitteeContactID / SM_TenantContactID are not assigned to separate new contacts. Preserve converted details in CSV/staging but do not claim those distinct details were imported. Do not create contacts or fabricate IDs.
- Open question for the team: the sample occupiers file conflicts with the roll/contacts. Its identity is unresolved. data-exclusions.json records its relative path and SHA-256; exclude it from tenant staging and Lot/Owner joins. Do not investigate or guess identity. A team-confirmed replacement needs an explicit policy update, not a boolean override.
- Old outputs are shape references, not golden data. The old Tenant output has nine rows while only five source records qualify as NO; its flags and other conversion flags contain inconsistent counts.
- Staging/master layouts, procedure signatures and the communication-preferences synonym were not inspected during file creation. Flattening requires a reviewed mapping to the live import contract, including conflicting contact slots and multiple committee members.


## Local DEV environment facts (this database only — re-verify before assuming for any other environment)

- F_SNG_UserAccounts_L3(NULL) does not return an ABOVEOCM row in this local DEV 
  database (confirmed 2026-09-19). This blocks the preflight check inside 
  ImportOwners' dependency chain. Until a real account-seed script is provided, 
  ask the user once per run whether to bypass this specific preflight for this 
  specific environment — a single lightweight confirmation, not a silent skip, 
  and never assumed for any other database.

- T_SNG_STRATA_Property_EntitlementTypes maps PropEntTypeID 1=Liability, 
  2=Voting Entitlement in this database (confirmed 2026-09-19 and re-verified 
  2026-09-21, with procedure/definition hashes recorded in that run's audit 
  files). The stock ImportLotEntitlements procedure inserts using the reversed 
  mapping. This has ONLY been confirmed against a property where Liability and 
  Voting totals happen to be numerically identical for every lot — the 
  correction has NOT been proven against a property where the two differ. 
  Apply the same correction as the verified run, but flag it explicitly in 
  every run's summary until Inesh or Maahir confirms which side is actually 
  wrong.

- The Committee-position reference table (Chairperson/Member IDs) has no rows 
  in this local DEV database (confirmed 2026-09-19) — a database seeding gap, 
  not a pipeline bug. Committee staging can still run; skip the Committee ERP 
  import step and say so in the run summary, same treatment as the Tenant gap.
