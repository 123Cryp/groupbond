# GroupBond

Shared-liability bonds for sales made inside Telegram, WhatsApp and Discord groups, built as a GenLayer Intelligent Contract with a static frontend.

A group admin locks a GEN pool and approves vendors. Each vendor posts their own bond. Every deal locks 50% of the protected amount from the vendor and 60% from the group pool. Buyers pay the vendor off-chain as they already do. If delivery fails, both sides submit evidence and GenLayer validators reach consensus on a verdict. The vendor's lock pays the buyer first, then the group pool covers the rest. A vendor who loses a dispute is suspended until the admin re-approves them.

## Layout

- `contracts/groupbond.py` - the Intelligent Contract (production windows, 1 hour unit)
- `contracts/groupbond_testnet.py` - generated variant with 5 second units for fast live testing
- `scripts/make_testnet.py` - regenerates the testnet variant
- `frontend/index.html` - single-file hash-routed app (genlayer-js, Studio network)
- `tests/` - offline test suite with a small GenLayer stub (no network, no pip)
- `ARCHITECTURE.md` - state machine, economics, limits

## Run the tests

    python3 -m unittest discover -s tests -t tests

## Deploy

1. Open GenLayer Studio, create a new file, paste `contracts/groupbond_testnet.py` (use `groupbond.py` for real time windows), deploy with no arguments.
2. Put the address in `DEFAULT_CONTRACT_ADDRESS` in `frontend/index.html`, or open the page with `?contract=ADDRESS`, or set it in the wallet menu.

## Honest limits

- The contract cannot see bank payments or parcels. It only weighs submitted evidence.
- Group handles and invite links are self-declared labels, not verified.
- Validators are language models and can be wrong. No appeal in v1.
- Links are never opened by validators.
- Not yet run on a live Studio deployment; only the offline stub tests were run.

MIT licensed.
