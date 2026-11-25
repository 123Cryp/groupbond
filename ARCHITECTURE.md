# Architecture

## Roles

- Group admin: one group per account. Posts a pool (min 10 GEN), approves, suspends or removes vendors.
- Vendor: belongs to one group. Posts a bond (min 3 GEN), needs admin approval, lists deals.
- Buyer: anyone else. Cannot be the vendor or the group admin of that deal.

An account has exactly one role.

## Vendor status

PENDING -> APPROVED (admin) -> SUSPENDED (admin, or automatically after a BUYER_WINS ruling) -> APPROVED (admin) ; PENDING/APPROVED/SUSPENDED -> REMOVED (admin or vendor, only with no active deals, final).

## Deal state machine

OPEN -> PAYMENT_CLAIMED -> ACTIVE -> DELIVERED -> COMPLETED
OPEN -> CANCELLED / EXPIRED
PAYMENT_CLAIMED -> OPEN (vendor rejects) or ACTIVE (vendor accepts, or anyone binds after the confirm window)
ACTIVE -> EXPIRED (deadline plus review window with no dispute)
ACTIVE or DELIVERED -> DISPUTED -> RESOLVED, or REOPENED once if evidence is insufficient, then RESOLVED
Silent-bound deals with a buyer-favourable ruling go to PAYOUT_PENDING for 7 days; the vendor can challenge once (CHALLENGED), otherwise anyone finalizes.

## Economics

- Vendor level from bond: STARTER (cap 4 GEN per deal), VERIFIED 10 GEN bond (cap 15), PREMIUM 30 GEN bond (cap 40).
- Lock per deal: vendor 50%, group pool 60% of the protected amount (110% total, enough for the 105% worst case).
- BUYER_WINS pays 100% of the protected amount, SPLIT 50%. A 5% fee on the compensation goes to the treasury. The vendor lock pays first, the group pool pays the remainder.
- Buyer posts a 1 GEN claim deposit and a 1 GEN dispute deposit. The dispute deposit is refunded unless the verdict is SELLER_WINS. The claim deposit is burned if the vendor rejects the claim.
- Accounting invariant: contract balance = vendor bonds + group pools + claimable + treasury + burned + held deposits. Payouts are pull payments through `claim()`.

## Anti-abuse

- Payable methods never revert on bad input; the value is credited to `claimable` and the call returns `REFUNDED:<reason>`.
- Deals bound by vendor silence cap compensation at 25%, need the judge's payment-review flag, and pay out only after a 7-day challenge window.
- Evidence is frozen with a sha256 digest, capped at 3 pieces per side, https links only.
- The judge prompt wraps untrusted text in `<DATA>` markers with angle brackets neutralised, uses a fixed rubric, and accepts only valid JSON with an allowed verdict. Group membership or admin vouching is not evidence.

## Previews (v1.1)

Two read-only views let a UI show the money before it moves. `quote(vendor, protect_amount)` returns the vendor lock, group lock and worst-case total for a listing, or the exact reason `create_deal` would refuse it. `preview_outcomes(deal_id)` returns buyer payment, fee, vendor-lock share and group-pool share for each of the three rulings, with the 25% silence cap applied when the vendor never confirmed payment. Both use the same arithmetic as `_settle`, and tests compare the preview with the real settlement for every ruling. They change no state.

## GenVM notes

Header lines are exactly the version line and the Depends line. No comments or docstrings in the contract. Collections are class-level annotations and never assigned in `__init__`. Views return JSON strings.

## Base port

- `GroupBondBase.sol` mirrors the Python state machine: same statuses, same lock maths, same payout order (vendor first, then pool).
- Differences: disputes are ruled by `arbiter` through `resolveDispute(id, verdict, reasonCode, reason, paymentEvidenceReviewed)`. The arbiter and owner are immutable and fixed at deploy (use a multisig), so there is no rotation. Bad input reverts with a compact custom error `Err(code)` instead of returning `REFUNDED:`; the frontend maps codes to the same reason keys. Read-only views live in a companion `GroupBondViews` contract that the main contract deploys in its constructor and reaches through a `fallback` delegatecall, so the main contract fits the EIP-170 limit; callers use one address and one ABI. Scores, levels and `free` are derived in the frontend rather than stored on-chain, to stay under the EIP-170 size limit.
- A silent-bound deal whose buyer win is not flagged as reviewed is downgraded to INSUFFICIENT_EVIDENCE, as in the Python contract.
- `tests/parity_scenarios.json` holds 76 dispute scenarios computed by an independent model in `scripts/gen_parity.py`. The Python suite replays them against the GenLayer contract and `ParityScenarios.t.sol` replays them against the Solidity contract.
