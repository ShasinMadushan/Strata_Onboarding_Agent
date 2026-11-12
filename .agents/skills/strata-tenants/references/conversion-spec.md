Reusable prompt for generating a Tenant Details CSV from a "current lot occupiers" file
=========================================================================================

Use this prompt (adjust the plan number / file name) for future plans:

"Read only the currentLotOccupiers CSV file for this plan (do not read the lot owners
report). For every row where Owner_Occupier = 'NO', the owner does not live in the lot,
so treat the listed contact as the tenant. Build a new CSV named
'Tenant Details Plan <PLAN_NUMBER>.csv' with these columns, in this order:

SM_Tenant_ContactName, SM_Tenant_BusinessName, SM_Tenant_Title, SM_Tenant_OtherNames,
SM_Tenant_BuildingName, SM_Tenant_StreetNumber, SM_Tenant_StreetName, SM_Tenant_Suburb,
SM_Tenant_StateCode, SM_Tenant_PostCode, SM_Tenant_PoBox, SM_Tenant_Country,
SM_Tenant_Mobile1, SM_Tenant_Mobile1_Note, SM_Tenant_Mobile2, SM_Tenant_Mobile2_Note,
SM_Tenant_LandLine1, SM_Tenant_LandLine1_Note, SM_Tenant_LandLine2, SM_Tenant_LandLine2_Note,
SM_Tenant_Email1, SM_Tenant_Email2, SM_Tenant_Email3, SM_Tenant_Fax,
SM_Tenant_IsBusinessContact, SM_Is_TenantContact, Lot_No, Unit_No, Plan_No

Mapping rules:
- Skip any row where Owner_Occupier = 'YES'.
- Name field: if it clearly reads as a company/business (contains words like Pty, Ltd,
  P/L, Trust, Trading, Co.), put it in SM_Tenant_BusinessName and set
  SM_Tenant_IsBusinessContact = 1. Otherwise treat as a person and put the first
  named person in SM_Tenant_ContactName, set SM_Tenant_IsBusinessContact = 0.
- If more than one person is named (joined by '&' or ','), put the full combined name
  (all persons, exactly as listed) into SM_Tenant_ContactName. Leave SM_Tenant_OtherNames
  blank — do not split additional names into it.
- Owners_Phone contains comma-separated 'Label: number' entries (e.g. 'Mobile 1: ...',
  'Mobile 2: ...', 'Home 1: ...', 'Work 1: ...'). Map the first two distinct mobile-type
  entries to Mobile1/Mobile2. Dedupe: if the same number is repeated (e.g. the same
  mobile listed twice), only record it once. Any remaining numbers (extra mobiles beyond
  the first two, or Home/Work entries) go into LandLine1/LandLine2 in order, up to two.
  Leave every *_Note field (Mobile1_Note, Mobile2_Note, LandLine1_Note, LandLine2_Note)
  blank by default. Only fill a *_Note field when the source data itself explicitly
  attributes that specific number to a named co-occupier (e.g. the source literally pairs
  a name with that number) — do not guess or infer whose number it is just because a row
  has multiple co-occupiers, and do not add a generic "this is actually a mobile" note
  without a specific attribution.
- Owners_Email contains comma-separated addresses; map them in source order to Email1,
  Email2, Email3 (drop any beyond three — usually agent/property-manager overflow
  addresses).
- Mailing_Address is formatted as '<Name>, <Unit> / <StreetNumber> <StreetName>,
  <Suburb>    <PostCode>'. Parse it in this exact order, working left to right from the
  first '/' in the address:
    1. Find the '/'. The token immediately BEFORE it is the unit number — this is
       already captured separately in the Unit_No column (see below), so do not repeat
       it here. The token immediately AFTER it is the real street/building number. It
       may be a single number ('44'), a range with a hyphen ('44-48', '63-67', '6-8'),
       or a larger number ('642').
    2. SM_Tenant_StreetNumber is that street/building number ALONE (e.g. '15', '44',
       '44-48', '642') — do not prefix it with the unit number and a '/'. The unit
       already has its own dedicated Unit_No column; do not duplicate it inside
       SM_Tenant_StreetNumber.
    3. Everything between the street number and the next comma is SM_Tenant_StreetName
       (e.g. 'Ferndale Close', 'Pacific Highway'). Do not leave the street number stuck
       inside this field (e.g. '642 Pacific Highway' is WRONG for StreetName; split into
       StreetNumber='642', StreetName='Pacific Highway').
    4. After the next comma: suburb, then (after 2+ spaces) the 4-digit postcode.
  Worked examples (source Mailing_Address -> output columns):
    'Jane Doe, 13 / 44 Ferndale Close, Constitution Hill    2145'
      -> StreetNumber='44', StreetName='Ferndale Close', Suburb='Constitution Hill',
         PostCode='2145' (Unit_No='13', taken separately from the source Unit column)
    'John Smith, 3 / 18-20 Pacific Highway, Roseville    2069'
      -> StreetNumber='18-20', StreetName='Pacific Highway' (Unit_No='3')
  If a row lists a second co-occupier with their own repeated copy of the address later
  in the same Mailing_Address string (e.g. joined by ', , <Name>, <Unit> / ...'), only
  parse the FIRST occurrence of '<Unit> / <StreetNumber> <StreetName>, <Suburb>
  <PostCode>' — ignore the duplicated tail.
  Self-check before writing each row: SM_Tenant_StreetNumber must be exactly the number
  right after the '/' in Mailing_Address — no unit prefix, no '/' in it (unless it's
  part of a hyphenated range like '44-48'), and it must NOT equal Unit_No unless the
  street number and unit genuinely happen to be the same value. If it contains a '/',
  re-parse the address — folding the unit into StreetNumber is exactly the mistake to
  avoid here, since the unit already has its own column.
  Infer SM_Tenant_StateCode and SM_Tenant_Country from the suburb/postcode using general
  knowledge (e.g. Wollstonecraft 2065 -> NSW, Australia) when it's unambiguous; otherwise
  leave blank.
- SM_Tenant_Title, SM_Tenant_BuildingName, and SM_Tenant_PoBox, SM_Tenant_Fax are left
  blank unless the source data explicitly provides them (Mailing_Address has no separate
  building name or PO box).
- SM_Is_TenantContact = 1 for every row (bit field, since every row in this file is a
  generated tenant contact).
- Add Lot_No and Unit_No as the next two columns, taken directly from the Lot_No and
  Unit columns of the source file.
- Add Plan_No as the last column, set to the plan number for every row (same value used
  in the output filename below) — this makes it possible to combine multiple plans'
  files into one CSV later while still knowing which property each row came from.
- Name the output file 'Tenant Details Plan <PLAN_NUMBER>.csv', using the plan number
  from the folder name (e.g. '_Plan 6309' -> 6309)."
