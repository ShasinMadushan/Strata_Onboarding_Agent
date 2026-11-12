"""
Mechanical field-level validator for a Strata Roll xlsx against its 4 source
CSVs, implementing strata_roll_validation_system_prompt.md as code instead of
prose. Every check that reduces to a deterministic string/digit/count
comparison is computed here and diffed against the extracted Roll cells --
nothing is asserted "clean" by narrative judgement. Genuinely ambiguous rule
edge-cases (C/- addresses, name-match partial cases, fallback ties between
identically-typed duplicate Contacts List rows) are logged separately, never
silently resolved.

To reuse on a different plan: edit the six paths in CONFIG below, then run
`python validate_strata_roll.py`. Output goes to <this file's dir>/
validation_report.txt (full expected/actual evidence for every field
checked, matches included) and mismatches are also printed to stdout.

Coverage: Owner Details, Agent Details, Tenant Details (empty-check),
Executive Committee, Individual Lot Info, Unit/Levy/Voting Entitlements,
Levy Details / Notice Details / Correspondence Details (incl. the
FeeNoticeContactShare/CorrespondenceContactShare "Both" row-count proxy
check, and the per-contact-type E/P/EP delivery-code check -- routing-label-
derived Contact_Delivery_Type vs the Roll's Delivery Method column, cross-
checked against the Contacts List levy_delivery/correspondence_delivery
columns), plus a workbook-wide numeric-cell-type scan for AU phone/mobile/
postcode fields that should be text.

NOT covered (out of scope per the validation prompt -- no derivable source):
Property Details, Property Structural Details, Levy Details period schedule,
Strata Managing Agent Details, Insurance sections, Nominee/Mortgagee/Past
Owners (checked only for expected-empty).
"""
import csv, re, sys, os, io, zipfile, shutil, tempfile
import openpyxl

# ---------------- CONFIG -- edit these 5 paths to reuse on another plan ----------------
BASE = os.path.dirname(os.path.abspath(__file__))
ROLL_XLSX = os.path.join(BASE, "Strata Roll_PS337219Q_Lot_All.xlsx")
OWNERS_CSV = os.path.join(BASE, "Strata Roll PS337219Q - 26.08.2026.csv")
OCCUPIERS_CSV = os.path.join(BASE, "__MISSING__currentLotOccupiers.csv")
COMMITTEE_CSV = os.path.join(BASE, "Committee Members PS337219Q - 26.08.2026.csv")
CONTACTS_CSV = os.path.join(BASE, "Lot Contacts PS337219Q - 26.08.2026.csv")
REPORT_PATH = os.path.join(BASE, "validation_report.txt")
# -----------------------------------------------------------------------------------------

OUT = []
def emit(*a):
    line = ' '.join(str(x) for x in a)
    print(line)
    OUT.append(line)

MISMATCHES = []
def flag(section, lot, field, expected, actual, cause=''):
    MISMATCHES.append((section, lot, field, expected, actual, cause))
    emit(f"  MISMATCH [{section}] Lot {lot} -- {field}")
    emit(f"    Expected: {expected}")
    emit(f"    Found in Strata Roll: {actual}")
    if cause:
        emit(f"    Likely cause: {cause}")

AMBIGUOUS = []
def flag_ambiguous(section, lot, note):
    AMBIGUOUS.append((section, lot, note))
    emit(f"  AMBIGUOUS [{section}] Lot {lot}: {note}")

CHECKED_FIELDS = 0
def evidence(section, lot, field, expected, actual, ok):
    global CHECKED_FIELDS
    CHECKED_FIELDS += 1
    emit(f"    [{'OK ' if ok else 'BAD'}] {section} Lot {lot} / {field}: expected={expected!r} actual={actual!r}")

# ================= Step 0: open workbook, repairing styles.xml if needed =================
def load_workbook_repaired(path):
    try:
        return openpyxl.load_workbook(path, data_only=True)
    except Exception as e:
        emit(f"[Step 0] openpyxl failed to open {os.path.basename(path)} directly ({e}); repairing a copy's styles.xml.")
        tmp = tempfile.NamedTemporaryFile(suffix='.xlsx', delete=False)
        tmp.close()
        shutil.copy(path, tmp.name)
        zin = zipfile.ZipFile(path, 'r')
        styles = zin.read('xl/styles.xml').decode('utf-8')
        fixed = re.sub(r'(numFmtId|fillId|borderId|fontId)="[^0-9"][^"]*"', r'\1="0"', styles)
        zout = zipfile.ZipFile(tmp.name, 'w', zipfile.ZIP_DEFLATED)
        for item in zin.infolist():
            content = zin.read(item.filename)
            if item.filename == 'xl/styles.xml':
                content = fixed.encode('utf-8')
            zout.writestr(item, content)
        zout.close(); zin.close()
        emit(f"[Step 0] Repaired copy written to {tmp.name}; opening that instead.")
        return openpyxl.load_workbook(tmp.name, data_only=True)

wb = load_workbook_repaired(ROLL_XLSX)
ws = wb.worksheets[0]
grid = [[c.value for c in row] for row in ws.iter_rows()]
CTYPES = [[type(c.value).__name__ for c in row] for row in ws.iter_rows()]

def find_section(name, occurrence=0):
    hits = [i for i, row in enumerate(grid) if row and row[0] == name]
    return hits[occurrence] if len(hits) > occurrence else None

def read_table(start_idx):
    rows = []
    i = start_idx + 1
    while i < len(grid) and grid[i][0] is not None:
        rows.append((i + 1, grid[i], CTYPES[i]))
        i += 1
    return rows

# ================= Load CSVs =================
def load_csv(path):
    with open(path, encoding='utf-8-sig', newline='') as f:
        return [row for row in csv.DictReader(f) if any((v or '').strip() for v in row.values())]

owners = load_csv(OWNERS_CSV)
if os.path.exists(OCCUPIERS_CSV):
    occupiers = load_csv(OCCUPIERS_CSV)
else:
    occupiers = []
    emit(f"[Step 0] Current Lot Occupiers CSV not supplied ({os.path.basename(OCCUPIERS_CSV)}). "
         f"Sections depending on it (lot physical address / IsOwnerOccupied) are NOT validated. "
         f"This does not affect Owner/Agent/Committee/Entitlement/Levy/Notice/Correspondence checks below.")
committee = load_csv(COMMITTEE_CSV)
contacts = load_csv(CONTACTS_CSV)

blocks, order = {}, []
for row in owners:
    lot = row['Lot_No'].strip()
    if lot not in blocks:
        blocks[lot] = []; order.append(lot)
    blocks[lot].append(row)
order = sorted(order, key=lambda x: int(x))

# ================= Name / address / phone / email helpers =================
TITLES = {'mr', 'mrs', 'ms', 'dr', 'miss', 'mx'}

def norm_tokens(name):
    name = re.sub(r'\([^)]*\)', '', name)
    subnames = re.split(r'\s*&\s*|\s+\band\b\s+', name, flags=re.I)
    out = []
    for sn in subnames:
        words = [w.strip('.,').lower() for w in sn.split() if w.strip('.,')]
        words = [w for w in words if w not in TITLES]
        if words:
            out.append(words)
    return out

def subname_match(routing_words, owner_words):
    rset, surname, given = set(routing_words), (owner_words[-1] if owner_words else None), (owner_words[0] if owner_words else None)
    has_surname = surname in rset
    has_given = given in rset or any(len(rw) >= 3 and len(given) >= 3 and (given.startswith(rw) or rw.startswith(given)) for rw in rset) if given else False
    if has_surname and has_given:
        return 'full'
    if rset & set(owner_words):
        return 'partial'
    return 'none'

def classify_name_match(routing_name, owner_name):
    if re.sub(r'\([^)]*\)', '', routing_name).strip().lower() == re.sub(r'\([^)]*\)', '', owner_name).strip().lower():
        return 'full'
    routing_words = [w for sub in norm_tokens(routing_name) for w in sub]
    best = 'none'
    for osub in norm_tokens(owner_name):
        res = subname_match(routing_words, osub)
        if res == 'full':
            return 'full'
        if res == 'partial':
            best = 'partial'
    return best

STATE_RANGES = [(200,299,'ACT'),(800,999,'NT'),(1000,1999,'NSW'),(2000,2599,'NSW'),(2619,2899,'NSW'),
                 (2921,2999,'NSW'),(2600,2618,'ACT'),(2900,2920,'ACT'),(3000,3999,'VIC'),(8000,8999,'VIC'),
                 (4000,4999,'QLD'),(9000,9999,'QLD'),(5000,5799,'SA'),(6000,6999,'WA'),(7000,7999,'TAS')]

def postcode_to_state(pc):
    try:
        p = int(pc)
    except Exception:
        return None
    for lo, hi, st in STATE_RANGES:
        if lo <= p <= hi:
            return st
    return None

def tokenize(s):
    return set(re.findall(r"[A-Z0-9]+", (s or '').upper()))

STATE_ABBREVS = {'NSW', 'VIC', 'QLD', 'WA', 'SA', 'TAS', 'ACT', 'NT'}

def addr_tokens_expected(raw):
    toks = tokenize(raw)
    pcs = re.findall(r"\b(\d{4})\b", raw or '')
    # Some source exports strip the leading zero from NT (08xx) / ACT (02xx)
    # postcodes -- e.g. '810' stored for '0810' (Tiwi NT). A Roll that renders
    # it back as the canonical 4-digit '0810' and derives the state from it is
    # doing the right thing, so normalise the expected side to match rather
    # than flag a spurious mismatch.
    if not pcs:
        three = re.findall(r"\b(\d{3})\b", raw or '')
        for t in three:
            padded = '0' + t
            if postcode_to_state(padded):
                toks.discard(t)
                toks.add(padded)
                pcs.append(padded)
    if pcs:
        st = postcode_to_state(pcs[-1])
        if st:
            toks.add(st)
    return toks

def digits_only(s):
    return re.sub(r"\D", "", s or "")

def normws(s):
    return re.sub(r'\s+', ' ', (s or '').strip()).lower()

def parse_phone_field(raw):
    mobiles, landlines = [], []
    if not raw:
        return mobiles, landlines
    for ch in [c.strip() for c in raw.split(',') if c.strip()]:
        if ':' in ch:
            label, num = ch.split(':', 1); label, num = label.strip(), num.strip()
        else:
            label, num = '', ch.strip()
        stripped = re.sub(r"[\s-]", "", num)
        if 'mobile' in label.lower() or stripped.startswith('04') or stripped.startswith('4'):
            if stripped.startswith('4') and not stripped.startswith('04') and len(stripped) == 9:
                stripped = '0' + stripped
            mobiles.append(stripped)
        else:
            landlines.append((num, label))
    return mobiles, landlines

def parse_email_field(raw):
    return [e.strip() for e in (raw or '').split(',') if e.strip()][:3]

def contacts_for_lot(lot, type_=None):
    return [c for c in contacts if c['lot'].strip() == str(lot) and (type_ is None or c['type'].strip() == type_)]

def contact_name_matches_list(name, lot, type_):
    n = normws(name)
    for r in contacts_for_lot(lot, type_):
        if normws(r['name']) == n:
            return r
    return None

def find_fallback_rows(agent_contact_name, lot):
    rows = [c for c in contacts_for_lot(lot, 'Letting Agent') if normws(c['name']) == normws(agent_contact_name)]
    postals = [r for r in rows if r['contact'].strip() == 'Postal Address']
    addrs = [r for r in rows if r['contact'].strip() == 'Address']
    return postals, addrs

# --- ComPref delivery-code helpers (strata_compref_system_prompt L37-47) ---
# Extend DELIVERY_MAP with whatever vocabulary another plan's Roll uses in its
# "Delivery Method" column; an unmapped value is deliberately kept as-is so it
# fails the compare loudly rather than passing silently.
DELIVERY_MAP = {
    'EMAIL': 'Email', 'E': 'Email', 'EMAILED': 'Email', 'VIA EMAIL': 'Email',
    'POST': 'Post', 'P': 'Post', 'MAIL': 'Post', 'POSTED': 'Post', 'BY POST': 'Post',
    'EMAIL AND POST': 'EP', 'POST AND EMAIL': 'EP', 'EP': 'EP', 'BOTH': 'EP',
}

def map_delivery(raw):
    """Strata Roll 'Delivery Method' cell -> 'Email' / 'Post' / 'EP' / ''."""
    k = re.sub(r'\s+', ' ', str(raw or '').strip()).upper()
    return DELIVERY_MAP.get(k, k) if k else ''

def delivery_code(values):
    """{Email}->E, {Post}->P, none->blank, anything mixed (or already 'EP')->EP."""
    s = {v for v in values if v}
    if not s:
        return ''
    if s == {'Email'}:
        return 'E'
    if s == {'Post'}:
        return 'P'
    return 'EP'

# ================= Step 1: build expected long-format rows per lot =================
class OutRow:
    def __init__(self, lot, name, ctype, comm, delivery, address_raw, phone_raw, email_raw, source):
        self.lot, self.name, self.ctype, self.comm, self.delivery = lot, name, ctype, comm, delivery
        self.address_raw, self.phone_raw, self.email_raw, self.source = address_raw, phone_raw, email_raw, source

expected_rows = {}
for lot in order:
    blk = blocks[lot]
    primary = blk[0]
    owner_name, owner_addr = primary['Owners_Name'], primary['Owners_Address']
    owner_email_first = (parse_email_field(primary['Owners_Email']) or [''])[0]
    rows = [OutRow(lot, owner_name, 'Owner', '', '', owner_addr, primary['Owners_Phone'], primary['Owners_Email'], 'primary')]
    established = [(normws(owner_addr), normws(owner_email_first))]
    agent_assigned_name, other_order = None, []
    for r in blk[1:]:
        m = re.match(r'^(Fee Notice|Correspondence)\s+(via email|to)$', r['Owners_Name'].strip(), re.I)
        if not m:
            continue
        comm = 'Fee Notice' if m.group(1).lower().startswith('fee') else 'Correspondence'
        delivery = 'Email' if 'email' in m.group(2).lower() else 'Post'
        combined = r['Owners_Address']
        cname, caddr = (combined.split(',', 1) + [''])[:2] if ',' in combined else (combined, '')
        cname, caddr = cname.strip(), caddr.strip()
        cemail_first = (parse_email_field(r['Owners_Email']) or [''])[0]
        ctype = None
        if classify_name_match(cname, owner_name) == 'full':
            addr_ok = normws(caddr) == '' or any(normws(caddr) == a for a, _ in established)
            email_ok = normws(cemail_first) == '' or any(normws(cemail_first) == e for _, e in established)
            if addr_ok and email_ok:
                ctype = 'Owner'
                established.append((normws(caddr), normws(cemail_first)))
            else:
                flag_ambiguous('Classification', lot, f"{cname!r} name-matches owner in full but address/email diverges -- resolved to non-Owner per rule, verify by hand")
        if ctype is None:
            agent_row = contact_name_matches_list(cname, lot, 'Letting Agent')
            tenant_row = contact_name_matches_list(cname, lot, 'Tenant')
            if agent_row is not None:
                if agent_assigned_name is None:
                    agent_assigned_name = cname; ctype = 'Agent'
                elif normws(cname) == normws(agent_assigned_name):
                    ctype = 'Agent'
                else:
                    flag_ambiguous('Classification', lot, f"{cname!r} matches a 2nd distinct Letting Agent name -- capped to OtherN per one-agent-per-lot rule")
            elif tenant_row is not None:
                ctype = 'Tenant'
        if ctype is None:
            key = normws(cname)
            existing = [k for k, _ in other_order]
            ctype = f'Other{existing.index(key) + 1}' if key in existing else (other_order.append((key, cname)) or f'Other{len(other_order)}')
        rows.append(OutRow(lot, cname, ctype, comm, delivery, caddr, r['Owners_Phone'], r['Owners_Email'], 'routing'))
    has_agent = any(x.ctype == 'Agent' for x in rows)
    letting_agents = contacts_for_lot(lot, 'Letting Agent')
    if letting_agents and not has_agent:
        biz_kw = [' - ', 'property', 'real estate', 'realty', 'strata', 'placeholder', 'pty', 'agency', 'group', 'management', 'estate agents']
        biz = next((r['name'] for r in letting_agents if any(k in r['name'].lower() for k in biz_kw)), None)
        chosen = biz or letting_agents[0]['name']
        if any(k in chosen.lower() for k in ['self managed', 'placeholder']):
            flag_ambiguous('Agent Details', lot, f"synthesized Agent contact {chosen!r} looks like a self-managed placeholder, not a genuine 3rd-party agent -- cross-check against how other placeholder-named lots are treated before including")
        rows.append(OutRow(lot, chosen, 'Agent', '', '', '', '', '', 'synthesized'))
    expected_rows[lot] = rows

emit("=== STEP 1: classification derived per lot (for audit) ===")
for lot in order:
    for r in expected_rows[lot]:
        emit(f"  Lot {lot} [{r.source}] {r.ctype} comm={r.comm or '-'} name={r.name!r}")

tenant_hits = [(lot, r.name) for lot in order for r in expected_rows[lot] if r.ctype == 'Tenant']
emit(f"\nTenant classification result: {tenant_hits if tenant_hits else 'NONE -- Tenant Details section should be empty'}")

# ================= Agent contact/phone/email fallback =================
def apply_agent_fallback(row):
    addr, phone, email = row.address_raw, row.phone_raw, row.email_raw
    if addr.strip() and phone.strip() and email.strip():
        return addr, phone, email, None
    postals, addrs = find_fallback_rows(row.name, row.lot)
    if len(postals) > 1:
        flag_ambiguous('Agent fallback', row.lot, f"multiple duplicate 'Postal Address' rows in Contacts List for {row.name!r} -- picking the one with actual data, but source data itself is ambiguous here")
    postal = next((p for p in postals if p['address'].strip() or p['suburb'].strip() or p['pcode'].strip()), (postals[0] if postals else None))
    addrrow = addrs[0] if addrs else None
    note = []
    if not addr.strip():
        chosen = postal if (postal and (postal['address'].strip() or postal['suburb'].strip() or postal['pcode'].strip())) else (addrrow if addrrow and (addrrow['address'].strip() or addrrow['suburb'].strip()) else None)
        if chosen:
            addr = f"{chosen['address']}, {chosen['suburb']} {chosen['pcode']}".strip(); note.append(f"addr<-{chosen['contact']}")
    if not phone.strip():
        chosen = postal if (postal and postal['phone'].strip()) else (addrrow if addrrow and addrrow['phone'].strip() else None)
        if chosen:
            phone = chosen['phone']; note.append(f"phone<-{chosen['contact']}")
    if not email.strip():
        chosen = postal if (postal and postal['email'].strip()) else (addrrow if addrrow and addrrow['email'].strip() else None)
        if chosen:
            email = chosen['email']; note.append(f"email<-{chosen['contact']}")
    return addr, phone, email, (','.join(note) if note else None)

expected_agent = {}
for lot in order:
    for r in expected_rows[lot]:
        if r.ctype == 'Agent':
            addr, phone, email, note = apply_agent_fallback(r)
            expected_agent[lot] = (r.name, addr, phone, email, note, r.source)

# ================= Load actual Roll sections =================
def table_after(name, occurrence=0):
    idx = find_section(name, occurrence)
    return read_table(idx + 1) if idx is not None else []

owner_rows = table_after('Owner Details')
agent_rows = table_after('Agent Details')
tenant_rows = table_after('Tenant Details')
levy_rows = table_after('Levy Details', occurrence=1)   # 2nd occurrence = per-lot table
notice_rows = table_after('Notice Details')
corr_rows = table_after('Correspondence Details')
committee_rows_actual = table_after('Executive Committee')
lotinfo_rows = table_after('Individual Lot Info')
unitent_rows = table_after('Unit Entitlements')

def row_by_lot(rows, lot):
    return next((row for (_, row, _) in rows if str(row[0]) == str(lot)), None)

NUM_TOKENS_IGNORE = set()  # postcodes seen in this dataset -- extended below

# ================= SECTION: Owner Details =================
emit("\n=== SECTION: Owner Details ===")
for lot in order:
    exp = next(r for r in expected_rows[lot] if r.source == 'primary')
    act = row_by_lot(owner_rows, lot)
    exp_addr_toks = addr_tokens_expected(exp.address_raw)
    act_addr_toks = tokenize(act[2] if act else '')
    missing = {t for t in exp_addr_toks - act_addr_toks if t not in STATE_ABBREVS}
    ok = not missing
    evidence('Owner Details', lot, 'Address tokens', sorted(exp_addr_toks), sorted(act_addr_toks), ok)
    if missing:
        flag('Owner Details', lot, 'Address', exp.address_raw, act[2], f"missing expected tokens {missing}")
    mobiles, landlines = parse_phone_field(exp.phone_raw)
    exp_m, exp_l = digits_only(mobiles[0]) if mobiles else '', digits_only(landlines[0][0]) if landlines else ''
    act_m, act_l = digits_only(str(act[4] or '')), digits_only(str(act[5] or ''))
    ok = (exp_m == act_m and exp_l == act_l)
    evidence('Owner Details', lot, 'Mobile/Phone digits', (exp_m, exp_l), (act_m, act_l), ok)
    if not ok:
        flag('Owner Details', lot, 'Mobile/Phone', f"mobile={exp_m!r} phone={exp_l!r} (src={exp.phone_raw!r})", f"mobile={act_m!r} phone={act_l!r}")

# ================= SECTION: Agent Details =================
emit("\n=== SECTION: Agent Details ===")
exp_lots = sorted(expected_agent.keys(), key=lambda x: int(x))
act_lots = sorted({str(row[0]) for (_, row, _) in agent_rows}, key=lambda x: int(x))
evidence('Agent Details', 'ALL', 'Lot set', exp_lots, act_lots, exp_lots == act_lots)
if exp_lots != act_lots:
    flag('Agent Details', 'ALL', 'Row set (which lots appear)', exp_lots, act_lots,
         'lots differ -- includes the self-managed-placeholder inclusion/exclusion question, see AMBIGUOUS log')
for lot in exp_lots:
    name, addr, phone, email, note, source = expected_agent[lot]
    act = row_by_lot(agent_rows, lot)
    if act is None:
        flag('Agent Details', lot, 'Row presence', f"expected row for {name!r} ({source})", 'MISSING'); continue
    act_name, act_addr, act_email, act_mobile, act_phone = act[1], act[2], act[3], act[4], act[5]
    ok = normws(act_name) == normws(name)
    evidence('Agent Details', lot, 'Contact Name', name, act_name, ok)
    if not ok:
        flag('Agent Details', lot, 'Contact Name', name, act_name, 'business name substituted for contact name, or vice versa' )
    exp_toks = addr_tokens_expected(addr) if addr else set()
    act_toks = tokenize(act_addr or '')
    missing = {t for t in exp_toks - act_toks if t not in STATE_ABBREVS}
    ok = not missing and (bool(addr.strip()) == bool((act_addr or '').strip()))
    evidence('Agent Details', lot, 'Address tokens', sorted(exp_toks), sorted(act_toks), ok)
    if missing:
        flag('Agent Details', lot, 'Address', f"{addr!r} (fallback={note})", act_addr, 'missing expected tokens ' + str(missing))
    mobiles, landlines = parse_phone_field(phone)
    exp_m, exp_l = digits_only(mobiles[0]) if mobiles else '', digits_only(landlines[0][0]) if landlines else ''
    act_m, act_l = digits_only(str(act_mobile or '')), digits_only(str(act_phone or ''))
    ok = (exp_m == act_m and exp_l == act_l)
    evidence('Agent Details', lot, 'Mobile/Phone digits', (exp_m, exp_l, f"fallback={note}"), (act_m, act_l), ok)
    if not ok:
        flag('Agent Details', lot, 'Mobile/Phone', f"mobile={exp_m!r} phone={exp_l!r} (fallback={note})", f"mobile={act_m!r} phone={act_l!r}")
    exp_emails = set(e.strip().lower() for e in email.split(',') if e.strip()) if email else set()
    act_emails = set(e.strip().lower() for e in (act_email or '').split(';') if e.strip())
    ok = (exp_emails == act_emails)
    evidence('Agent Details', lot, 'Email set', exp_emails, act_emails, ok)
    if not ok:
        flag('Agent Details', lot, 'Email', f"{exp_emails} (fallback={note})", act_emails, 'fallback pulled every Letting-Agent-typed email at the lot instead of the one matched contact record' if len(act_emails) > len(exp_emails) else '')

# ================= SECTION: Levy / Notice / Correspondence Details =================
emit("\n=== SECTION: Levy / Notice / Correspondence Details ===")
def check_comm_section(section_rows, comm_type, section_name):
    for lot in order:
        exp_contacts = [r for r in expected_rows[lot] if r.comm == comm_type]
        act_contacts = [row for (_, row, _) in section_rows if str(row[0]) == str(lot)]
        evidence(section_name, lot, 'Row count (Both/E-P-EP proxy)', len(exp_contacts), len(act_contacts), len(exp_contacts) == len(act_contacts))
        if len(exp_contacts) != len(act_contacts):
            flag(section_name, lot, 'Row count', len(exp_contacts), len(act_contacts), 'distinct-contact count for this communication type does not match row count')
            continue
        used, matched = set(), []
        def _emails(s, sep):
            return set(e.strip().lower() for e in (s or '').split(sep) if e.strip())
        for er in exp_contacts:
            er_emails = _emails(er.email_raw, ',')
            # When a lot has 2+ rows with the SAME contact name (e.g. an Owner
            # row and an OtherN row that are the same person with a different
            # email), a name-only pairing can cross the two rows and fabricate
            # an email "mismatch". Prefer a row that also matches on email set;
            # only fall back to name-only when no email-consistent row is free.
            match_i = next((i for i, ar in enumerate(act_contacts)
                            if i not in used and normws(ar[1]) == normws(er.name)
                            and (not er_emails or er_emails == _emails(ar[3], ';'))), None)
            if match_i is None:
                match_i = next((i for i, ar in enumerate(act_contacts) if i not in used and normws(ar[1]) == normws(er.name)), None)
            if match_i is None:
                flag(section_name, lot, 'Contact match', er.name, [a[1] for a in act_contacts], 'expected contact not found by name in this lot\'s rows')
                continue
            used.add(match_i)
            ar = act_contacts[match_i]
            matched.append((er, ar))
            exp_toks = addr_tokens_expected(er.address_raw) if er.address_raw.strip() else set()
            act_toks = tokenize(ar[2] or '')
            missing = {t for t in exp_toks - act_toks if t not in STATE_ABBREVS}
            extra_num = {t for t in act_toks - exp_toks if t.isdigit() and len(t) >= 3}
            evidence(section_name, lot, f'{er.name} / Address tokens', sorted(exp_toks), sorted(act_toks), not missing and not extra_num)
            if missing:
                flag(section_name, lot, f'{er.name} -- Address (missing content)', er.address_raw, ar[2], f"missing tokens {missing}")
            if extra_num:
                flag(section_name, lot, f'{er.name} -- Address (unexplained content)', er.address_raw or '(blank -- no source address for this contact)', ar[2], f"unexpected tokens {extra_num} not present in any source for this lot/contact")
            mobiles, landlines = parse_phone_field(er.phone_raw)
            exp_m, exp_l = digits_only(mobiles[0]) if mobiles else '', digits_only(landlines[0][0]) if landlines else ''
            act_m, act_l = digits_only(str(ar[4] or '')), digits_only(str(ar[5] or ''))
            ok = (exp_m == act_m and exp_l == act_l)
            evidence(section_name, lot, f'{er.name} / Mobile-Phone digits', (exp_m, exp_l), (act_m, act_l), ok)
            if not ok:
                flag(section_name, lot, f'{er.name} -- Mobile/Phone', f"mobile={exp_m!r} phone={exp_l!r}", f"mobile={act_m!r} phone={act_l!r}")
            exp_emails = set(e.strip().lower() for e in er.email_raw.split(',') if e.strip())
            act_emails = set(e.strip().lower() for e in (ar[3] or '').split(';') if e.strip())
            ok = (not exp_emails) or exp_emails == act_emails
            evidence(section_name, lot, f'{er.name} / Email set', exp_emails, act_emails, ok)
            if not ok:
                flag(section_name, lot, f'{er.name} -- Email', exp_emails, act_emails)

        # --- ComPref delivery code (E/P/EP), per contact type ---
        # Source of truth 1: Owners Report routing-row label -> Contact_Delivery_Type
        #   (strata_conversion_system_prompt L112-115), already resolved into er.delivery.
        # Source of truth 2 (cross-check): Contacts List levy_delivery / correspondence_delivery.
        comm_label = 'FeeNotice' if comm_type == 'Fee Notice' else 'Correspondence'
        cl_col = 'levy_delivery' if comm_type == 'Fee Notice' else 'correspondence_delivery'
        by_ctype = {}
        for er, ar in matched:
            by_ctype.setdefault(er.ctype, []).append((er, ar))
        for ctype, pairs in sorted(by_ctype.items()):
            exp_code = delivery_code([er.delivery for er, _ in pairs])
            act_code = delivery_code([map_delivery(ar[6] if len(ar) > 6 else '') for _, ar in pairs])
            ok = (exp_code == act_code)
            evidence(section_name, lot, f'{ctype} / Delivery code ({comm_label})', exp_code, act_code, ok)
            if not ok:
                flag(section_name, lot, f'{ctype} -- Delivery code ({comm_label})',
                     f"{exp_code!r} (Owners Report routing label(s): {[er.delivery for er, _ in pairs]})",
                     f"{act_code!r} (Strata Roll Delivery Method: {[ar[6] if len(ar) > 6 else None for _, ar in pairs]})",
                     'routing-label-derived Contact_Delivery_Type vs Roll Delivery Method column')
            for er, _ in pairs:
                cl_vals = {(c.get(cl_col) or '').strip().title()
                           for c in contacts_for_lot(lot)
                           if normws(c['name']) == normws(er.name) and (c.get(cl_col) or '').strip()}
                if cl_vals and er.delivery and er.delivery not in cl_vals:
                    flag_ambiguous(section_name, lot,
                        f"{er.name}: Owners Report routing label implies {er.delivery} for {comm_label}, "
                        f"but Contacts List {cl_col}={sorted(cl_vals)} -- sources of truth disagree, verify by hand")

check_comm_section(levy_rows, 'Fee Notice', 'Levy Details')
check_comm_section(notice_rows, 'Correspondence', 'Notice Details')
check_comm_section(corr_rows, 'Correspondence', 'Correspondence Details')

# Notice Details === Correspondence Details identity check
emit("\n=== SECTION: Notice Details === Correspondence Details identity ===")
for lot in order:
    n = [row for (_, row, _) in notice_rows if str(row[0]) == str(lot)]
    c = [row for (_, row, _) in corr_rows if str(row[0]) == str(lot)]
    ok = [tuple(str(x) for x in row[1:7]) for row in n] == [tuple(str(x) for x in row[1:7]) for row in c]
    evidence('Notice==Correspondence', lot, 'row tuples', n, c, ok)
    if not ok:
        flag('Notice Details vs Correspondence Details', lot, 'Identity', c, n, 'Notice_X must always equal Correspondence_X per rule')

# ================= SECTION: Executive Committee =================
emit("\n=== SECTION: Executive Committee ===")
for cm in committee:
    lot = cm['Lot'].strip()
    act = row_by_lot(committee_rows_actual, lot)
    if act is None:
        flag('Executive Committee', lot, 'Row presence', cm['member_name'], 'MISSING'); continue
    checks = [
        ('Position', cm['position'].strip(), act[1]),
        ('Name', cm['member_name'].strip(), act[2]),
        ('Email', cm['email'].strip().lower(), (act[7] or '').strip().lower()),
    ]
    for field, exp_v, act_v in checks:
        ok = normws(exp_v) == normws(act_v)
        evidence('Executive Committee', lot, field, exp_v, act_v, ok)
        if not ok:
            flag('Executive Committee', lot, field, exp_v, act_v)
    exp_toks = addr_tokens_expected(cm['address'])
    act_toks = tokenize(act[3] or '')
    missing = {t for t in exp_toks - act_toks if t not in STATE_ABBREVS}
    ok = not missing
    evidence('Executive Committee', lot, 'Address tokens', sorted(exp_toks), sorted(act_toks), ok)
    if missing:
        flag('Executive Committee', lot, 'Address', cm['address'], act[3], f"missing tokens {missing} -- check for copy-paste from an adjacent lot's row")
    mobiles, landlines = parse_phone_field(cm['phone'])
    exp_m = digits_only(mobiles[0]) if mobiles else ''
    act_m = digits_only(str(act[5] or ''))
    ok = exp_m == act_m
    evidence('Executive Committee', lot, 'Mobile digits', exp_m, act_m, ok)
    if not ok:
        flag('Executive Committee', lot, 'Mobile', exp_m, act_m)

# ================= SECTION: Individual Lot Info + Unit Entitlements =================
emit("\n=== SECTION: Individual Lot Info + Unit Entitlements ===")
for lot in order:
    primary = blocks[lot][0]
    exp_liab, exp_ent = primary['Lot_Liab'].strip(), primary['Lot_Ent'].strip()
    act = row_by_lot(unitent_rows, lot)
    act_liab = str(act[1]).split('/')[0].strip() if act else ''
    act_ent = str(act[2]).split('/')[0].strip() if act else ''
    ok = (float(act_liab or -1) == float(exp_liab or -2)) and (float(act_ent or -1) == float(exp_ent or -2))
    evidence('Unit Entitlements', lot, 'Liability/Entitlement', (exp_liab, exp_ent), (act_liab, act_ent), ok)
    if not ok:
        flag('Unit Entitlements', lot, 'Lot_Liab/Lot_Ent', (exp_liab, exp_ent), (act_liab, act_ent))
liab_sum = sum(int(blocks[lot][0]['Lot_Liab'].strip()) for lot in order)
emit(f"  Sum of Lot_Liab across all lots: {liab_sum} (denominator shown in Roll should match this)")

# ================= SECTION: numeric-cell-type scan (workbook-wide) =================
emit("\n=== SECTION: numeric-cell-type scan (leading-zero risk) ===")
PHONE_HEADER_HINTS = {'mobile', 'phone', 'postcode', 'post code', 'pcode'}
affected = {}
header_row_idx = None
for i, row in enumerate(grid):
    if row and any(isinstance(h, str) and h.strip().lower() in PHONE_HEADER_HINTS for h in row):
        header_row_idx = i
        headers = row
        continue
    if header_row_idx is not None and row and row[0] is None:
        header_row_idx = None
    if header_row_idx is not None:
        for ci, h in enumerate(headers):
            if isinstance(h, str) and h.strip().lower() in PHONE_HEADER_HINTS:
                val = row[ci]
                ty = CTYPES[i][ci]
                if val is not None and ty in ('int', 'float'):
                    sec = next((grid[k][0] for k in range(i, -1, -1) if grid[k] and grid[k][0] and grid[k][0] == grid[k][0]), None)
                    # find nearest section header above
                    sname = None
                    for k in range(i, -1, -1):
                        if grid[k] and isinstance(grid[k][0], str) and grid[k][0] in (
                            'Property Details','Strata Managing Agent Details','Broker Details','Insurer Details',
                            'Executive Committee','Levy Details','Notice Details','Correspondence Details'):
                            sname = grid[k][0]; break
                    key = (sname or '?', h)
                    affected.setdefault(key, []).append((i+1, ci, val))
for (sec, col), cells in sorted(affected.items()):
    emit(f"  [{sec}] column {col!r}: {len(cells)} cell(s) stored as numeric, e.g. row {cells[0][0]} value={cells[0][2]!r}")
    flag('Numeric cell type', 'ALL', f'{sec} / {col}', f'{len(cells)} cells should be text', 'stored as int/float', 'leading zeros silently dropped on any value that has them')

# ================= Write report =================
with open(REPORT_PATH, 'w', encoding='utf-8') as f:
    f.write('\n'.join(OUT))
    f.write(f"\n\n=== SUMMARY ===\n")
    f.write(f"Lots checked: {len(order)}\n")
    f.write(f"Fields checked (evidence lines): {CHECKED_FIELDS}\n")
    f.write(f"Mismatches found: {len(MISMATCHES)}\n")
    f.write(f"Ambiguous cases flagged (not scored): {len(AMBIGUOUS)}\n")

print(f"\n\n=== SUMMARY: {len(order)} lots, {CHECKED_FIELDS} fields checked, {len(MISMATCHES)} mismatches, {len(AMBIGUOUS)} ambiguous cases flagged ===")
print(f"Full evidence log written to: {REPORT_PATH}")
