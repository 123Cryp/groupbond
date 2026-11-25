# GroupBond

Shared-liability bonds for sales made inside Telegram, WhatsApp and Discord groups, built as a GenLayer Intelligent Contract with a static frontend.

A group admin locks a GEN pool and approves vendors. Each vendor posts their own bond. Every deal locks 50% of the protected amount from the vendor and 60% from the group pool. Buyers pay the vendor off-chain as they already do. If delivery fails, both sides submit evidence and GenLayer validators reach consensus on a verdict. The vendor's lock pays the buyer first, then the group pool covers the rest. A vendor who loses a dispute is suspended until the admin re-approves them.

## Layout

- `contracts/groupbond.py` - the Intelligent Contract (production windows, 1 hour unit)
- `contracts/groupbond_testnet.py` - generated variant with 5 second units for fast live testing
- `scripts/make_testnet.py` - regenerates the testnet variant
- `frontend/index.html` - single-file hash-routed app (genlayer-js, Studio network)
- `base/` - Solidity port for Base (`src/GroupBondBase.sol`), Foundry tests and deploy script
- `frontend/base.html` - the same app on viem for Base and Base Sepolia, also a Farcaster mini app (`frontend/.well-known/farcaster.json`)
- `scripts/gen_parity.py` - writes the parity scenarios used by both test suites
- `scripts/gen_url_tests.py` - writes the Solidity URL test from `tests/url_vectors.json`
- `scripts/gen_abi.py` - prints the ABI that is embedded in `frontend/base.html`
- `tests/` - offline test suite with a small GenLayer stub (no network, no pip)
- `ARCHITECTURE.md` - state machine, economics, limits

## v1.1: previews

- `quote(vendor, protect_amount)` shows the locks a listing would take, or why the contract would refuse it. The vendor page calls it while you type.
- `preview_outcomes(deal_id)` shows what each ruling would pay. The deal page shows it as "What each ruling would pay".
- The Base port does not have these views yet.

## Run the tests

    python3 -m unittest discover -s tests -t tests

## Deploy

1. Open GenLayer Studio, create a new file, paste `contracts/groupbond_testnet.py` (use `groupbond.py` for real time windows), deploy with no arguments.
2. Put the address in `DEFAULT_CONTRACT_ADDRESS` in `frontend/index.html`, or open the page with `?contract=ADDRESS`, or set it in the wallet menu.

## Base version

The Base contract keeps the same money rules (50% vendor lock, 60% group lock, 5% fee, 25% cap on deals the vendor never answered, 168 hour payout challenge window) but replaces validator consensus with an arbiter address, ideally a multisig. Amounts are scaled 1 GEN to 0.001 ETH.

    cd base
    forge install foundry-rs/forge-std
    forge test
    ARBITER=0x... TIME_UNIT=3600 forge script script/Deploy.s.sol --rpc-url $RPC --broadcast --private-key $KEY

The `Base contract tests` GitHub workflow runs `forge build` and `forge test` on every push to `base/`. Set `TIME_UNIT=5` and `ALLOW_EOA_ARBITER=true` for a fast testnet deployment.

Open `frontend/base.html?contract=ADDRESS&chain=sepolia` (or `chain=base`). The ABI inside the page is generated from the Solidity file and checked by a test.

## Honest limits

- The contract cannot see bank payments or parcels. It only weighs submitted evidence.
- Group handles and invite links are self-declared labels, not verified.
- Validators are language models and can be wrong. No appeal in v1.
- Links are never opened by validators.
- Run on a live Studio deployment (testnet variant): two deals, one ending in a SPLIT verdict, all transactions accepted. The offline stub tests cover the rest.
- The Solidity contract was compiled and tested only through the Foundry workflow (111 tests passing). It has not been deployed to Base or Base Sepolia yet.
- On Base the arbiter is trusted. Nothing on-chain forces it to rule fairly; a timeout lets anyone close a stalled dispute with no payout.

MIT licensed.
