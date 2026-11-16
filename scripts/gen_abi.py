import json
import pathlib
import re

root = pathlib.Path(__file__).resolve().parent.parent
SRC = root / "base" / "src" / "GroupBondBase.sol"
ENUMS = ("Status", "Verdict", "VendorStatus")
EXPORT = (
    "createGroup", "addPool", "withdrawPool", "joinGroup", "addBond", "withdrawBond", "approveVendor",
    "suspendVendor", "removeVendor", "leaveGroup", "createDeal", "cancelDeal", "expireOffer", "claimPayment",
    "respondPayment", "bindByTimeout", "submitDelivery", "confirmDelivery", "finalizeDeal", "openDispute",
    "submitEvidence", "challengePayout", "finalizePayout", "closeStalledDispute", "claim", "collectFees",
    "getDeal", "getEvidence", "groupInfo", "groupCount", "groupAt", "groupOf", "vendorInfo", "isVendor",
    "vendorByHandle", "vendorCount", "vendorAt", "getProtection", "isProtected", "totalBonds", "totalPools",
)
PUBLIC_VARS = (
    "unit", "offerWindow", "confirmWindow", "reviewWindow", "evidenceWindow", "reopenWindow", "arbiterTimeout",
    "payoutDelay", "trustedMinAge", "owner", "arbiter", "treasury", "burned", "depositsHeld", "totalClaimable",
    "dealCount",
)
PUBLIC_CONSTS = (
    "MIN_POOL", "MIN_BOND", "VERIFIED_BOND", "PREMIUM_BOND", "MAX_PROTECT_STARTER", "MAX_PROTECT_VERIFIED",
    "MAX_PROTECT_PREMIUM", "MIN_PROTECT", "DISPUTE_DEPOSIT", "CLAIM_DEPOSIT", "VENDOR_BPS", "GROUP_BPS", "FEE_BPS",
    "TIMEOUT_CAP_BPS", "MAX_EVIDENCE_PER_SIDE",
)


def structs(src):
    out = {}
    for m in re.finditer(r"struct\s+(\w+)\s*\{(.*?)\}", src, re.S):
        fields = []
        for line in m.group(2).split(";"):
            line = line.strip()
            if not line:
                continue
            t, n = line.rsplit(None, 1)
            fields.append((t, n))
        out[m.group(1)] = fields
    return out


def abi_type(t, st):
    arr = ""
    if t.endswith("[]"):
        t, arr = t[:-2], "[]"
    if t in ENUMS:
        return {"type": "uint8" + arr}
    if t in st:
        return {"type": "tuple" + arr, "components": [dict(name=n, **abi_type(ft, st)) for ft, n in st[t]]}
    return {"type": t + arr}


def params(text, st):
    out = []
    text = text.strip()
    if not text:
        return out
    for part in text.split(","):
        bits = part.split()
        t = bits[0]
        name = bits[-1] if len(bits) > 1 and bits[-1] not in ("memory", "calldata") else ""
        out.append(dict(name=name, **abi_type(t, st)))
    return out


def render():
    src = SRC.read_text()
    st = structs(src)
    abi = []
    pat = r"function\s+(\w+)\s*\(([^)]*)\)\s*((?:(?:external|public|internal|private|payable|view|pure|onlyOwner|nonReentrant)\s*)+)(?:returns\s*\(([^)]*)\)\s*)?\{"
    for m in re.finditer(pat, src):
        name, ins, mods, outs = m.groups()
        if name not in EXPORT:
            continue
        mut = "payable" if "payable" in mods else "view" if "view" in mods else "pure" if "pure" in mods else "nonpayable"
        abi.append({"type": "function", "name": name, "stateMutability": mut, "inputs": params(ins, st), "outputs": params(outs or "", st)})
    for name in PUBLIC_VARS:
        t = re.search(r"(\w+)\s+public\s+(?:immutable\s+)?%s\b" % name, src).group(1)
        abi.append({"type": "function", "name": name, "stateMutability": "view", "inputs": [], "outputs": [{"name": "", "type": t}]})
    for name in PUBLIC_CONSTS:
        abi.append({"type": "function", "name": name, "stateMutability": "view", "inputs": [], "outputs": [{"name": "", "type": "uint256"}]})
    abi.append({"type": "function", "name": "claimable", "stateMutability": "view", "inputs": [{"name": "", "type": "address"}], "outputs": [{"name": "", "type": "uint256"}]})
    abi.append({"type": "error", "name": "Err", "inputs": [{"name": "code", "type": "uint8"}]})
    names = {a["name"] for a in abi}
    missing = [n for n in EXPORT if n not in names]
    if missing:
        raise SystemExit("missing in source: " + ", ".join(missing))
    return json.dumps(abi, separators=(",", ":"))


def error_names():
    src = SRC.read_text()
    body = re.search(r"enum E \{(.*?)\}", src, re.S).group(1)
    return [n.strip() for n in body.split(",") if n.strip()]


def snake(name):
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def render_errors():
    return json.dumps([snake(n) for n in error_names()], separators=(",", ":"))


if __name__ == "__main__":
    print(render())
