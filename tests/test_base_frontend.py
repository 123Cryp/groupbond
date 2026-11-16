import json
import pathlib
import re
import subprocess
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent


class TestBaseFrontend(unittest.TestCase):
    def setUp(self):
        self.html = (ROOT / "frontend" / "base.html").read_text()
        self.sol = (ROOT / "base" / "src" / "GroupBondBase.sol").read_text()

    def test_embedded_abi_matches_solidity(self):
        fresh = subprocess.check_output([sys.executable, str(ROOT / "scripts" / "gen_abi.py")], text=True).strip()
        m = re.search(r"/\*ABI_START\*/(.*?)/\*ABI_END\*/", self.html, re.S)
        self.assertIsNotNone(m)
        self.assertEqual(json.loads(m.group(1)), json.loads(fresh))

    def test_embedded_error_names_match_solidity(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("gen_abi", ROOT / "scripts" / "gen_abi.py")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        m = re.search(r"/\*ERR_START\*/(.*?)/\*ERR_END\*/", self.html, re.S)
        self.assertIsNotNone(m)
        self.assertEqual(json.loads(m.group(1)), json.loads(mod.render_errors()))
        for key in ("wrong_deposit", "claim_was_rejected", "pool_below_minimum", "vendor_cannot_buy_own_deal"):
            self.assertIn(key, json.loads(m.group(1)))

    def test_every_abi_function_exists_in_source(self):
        abi = json.loads(re.search(r"/\*ABI_START\*/(.*?)/\*ABI_END\*/", self.html, re.S).group(1))
        for item in abi:
            n = item["name"]
            if item["type"] == "error":
                continue
            self.assertTrue(re.search(r"function\s+%s\s*\(" % n, self.sol) or re.search(r"\bpublic\s+(?:constant\s+|immutable\s+)?%s\b" % n, self.sol), n)

    def test_every_write_call_targets_a_payable_or_nonpayable_function(self):
        abi = {a["name"]: a for a in json.loads(re.search(r"/\*ABI_START\*/(.*?)/\*ABI_END\*/", self.html, re.S).group(1))}
        for m in re.finditer(r'^\s+\w+: \["(\w+)", ', self.html, re.M):
            self.assertIn(m.group(1), abi)
            self.assertIn(abi[m.group(1)]["stateMutability"], ("payable", "nonpayable"))

    def test_base_page_has_no_genlayer_leftovers(self):
        for bad in ("genlayer", "GenLayer", "Studio", "studionet", "validator"):
            self.assertNotIn(bad, self.html)

    def test_farcaster_manifest_points_at_base_page(self):
        data = json.loads((ROOT / "frontend" / ".well-known" / "farcaster.json").read_text())
        self.assertEqual(data["miniapp"]["name"], "GroupBond")
        self.assertTrue(data["miniapp"]["homeUrl"].endswith("/base.html"))

    def test_solidity_constants_match_python_contract(self):
        py = (ROOT / "contracts" / "groupbond.py").read_text()
        for name in ("VENDOR_BPS", "GROUP_BPS", "FEE_BPS", "TIMEOUT_CAP_BPS", "MAX_EVIDENCE_PER_SIDE", "PAIR_CREDIT_LIMIT", "TRUSTED_MIN_COMPLETED", "TRUSTED_MIN_VERIFIED", "TRUSTED_MIN_UNIQUE", "EVIDENCE_REOPEN_BONUS"):
            a = re.search(r"^%s = (\d+)$" % name, py, re.M).group(1)
            b = re.search(r"%s = (\d+);" % name, self.sol).group(1)
            self.assertEqual(a, b, name)
        ratio = {"MIN_POOL": 10, "MIN_BOND": 3, "VERIFIED_BOND": 10, "PREMIUM_BOND": 30, "MAX_PROTECT_STARTER": 4, "MAX_PROTECT_VERIFIED": 15, "MAX_PROTECT_PREMIUM": 40, "MIN_PROTECT": 1, "DISPUTE_DEPOSIT": 1, "CLAIM_DEPOSIT": 1}
        for name, units in ratio.items():
            m = re.search(r"%s = ([\d.]+) ether;" % name, self.sol)
            self.assertEqual(round(float(m.group(1)) * 1000), units, name)
            self.assertIn("%s = %d * GEN" % (name, units), py)


if __name__ == "__main__":
    unittest.main()
