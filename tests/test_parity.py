import importlib.util
import json
import pathlib
import unittest

from _bootstrap import Chain, A, gl
from test_groupbond import GEN, UNIT, verdict_json

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADMIN, VENDOR, BUYER, STRANGER = A(2), A(3), A(4), A(6)
MICRO_WEI = 10 ** 12


def load_gen():
    spec = importlib.util.spec_from_file_location("gen_parity", ROOT / "scripts" / "gen_parity.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run_genlayer(sc):
    ch = Chain()
    for who in (ADMIN, VENDOR, BUYER, STRANGER):
        ch.fund(who, 1000 * GEN)
    ch.call(ADMIN, "create_group", "parity_hub", "Parity Hub", "telegram", "", value=50 * GEN)
    ch.call(VENDOR, "join_group", "parity_hub", "parity_shop", value=50 * GEN)
    ch.call(ADMIN, "approve_vendor", VENDOR)
    did = ch.call(VENDOR, "create_deal", "Parity item", "1 USD", "", sc["protect"] * GEN, 48)
    ch.call(BUYER, "claim_payment", did, "bank ref 123456", value=GEN)
    if sc["silent"]:
        ch.advance(24 * UNIT)
        ch.call(STRANGER, "bind_by_timeout", did)
    else:
        ch.call(VENDOR, "respond_payment", did, True, "")
    ch.advance(48 * UNIT + 1)
    ch.call(BUYER, "open_dispute", did, "nothing was ever sent", "", value=GEN)
    ch.advance(48 * UNIT + 1)
    for i, st in enumerate(sc["steps"]):
        if st[0] == "c":
            ch.call(VENDOR, "challenge_payout", did, "I never saw this payment", "")
        elif st[0] == "f":
            ch.advance(168 * UNIT)
            ch.call(STRANGER, "finalize_payout", did)
        else:
            if i > 0:
                ch.advance(24 * UNIT + 1)
            v, rev = st[1], st[2]
            gl.nondet.exec_prompt = lambda p, response_format="text", v=v, rev=rev: verdict_json(v, reviewed=rev)
            ch.call(STRANGER, "resolve_dispute", did)
    d = json.loads(ch.c.get_deal(did))
    v = json.loads(ch.c.get_vendor(VENDOR))
    g = json.loads(ch.c.get_group("parity_hub"))
    acc = json.loads(ch.c.get_accounting())
    m = lambda x: int(x) // MICRO_WEI
    return {
        "status": d["status"],
        "verdict": d["verdict"],
        "compensation": m(d["compensation"]),
        "fee": m(d["fee"]),
        "paid_vendor": m(d["paid_vendor"]),
        "paid_group": m(d["paid_group"]),
        "buyer_claimable": m(ch.c.get_claimable(BUYER)),
        "vendor_claimable": m(ch.c.get_claimable(VENDOR)),
        "treasury": m(acc["treasury"]),
        "vendor_bond": m(v["bond"]),
        "vendor_locked": m(v["locked"]),
        "group_pool": m(g["pool"]),
        "group_locked": m(g["locked"]),
        "vendor_suspended": 1 if v["status"] == "SUSPENDED" else 0,
        "lost": v["disputes_lost"],
        "split": v["disputes_split"],
        "won": v["disputes_won"],
        "inconclusive": v["inconclusive"],
        "group_lost": g["disputes_lost"],
        "group_won": g["disputes_won"],
    }


class TestParity(unittest.TestCase):
    def test_scenarios_match_reference_model(self):
        data = json.loads((ROOT / "tests" / "parity_scenarios.json").read_text())
        self.assertGreater(len(data["scenarios"]), 50)
        for sc in data["scenarios"]:
            self.assertEqual(run_genlayer(sc), sc["expect"], sc["id"])

    def test_generated_files_are_current(self):
        gen = load_gen()
        self.assertEqual((ROOT / "tests" / "parity_scenarios.json").read_text(), gen.render_json())
        self.assertEqual((ROOT / "base" / "test" / "ParityScenarios.t.sol").read_text(), gen.render_sol())

    def test_url_vector_test_is_current(self):
        spec = importlib.util.spec_from_file_location("gen_url_tests", ROOT / "scripts" / "gen_url_tests.py")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        self.assertEqual((ROOT / "base" / "test" / "UrlVectors.t.sol").read_text(), mod.render())


if __name__ == "__main__":
    unittest.main()
