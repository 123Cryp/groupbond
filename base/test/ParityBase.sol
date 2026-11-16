// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/GroupBondBase.sol";

abstract contract ParityBase is Test {
    struct Obs {
        bool reverted;
        uint256 status;
        uint256 verdict;
        uint256 compensation;
        uint256 fee;
        uint256 paidVendor;
        uint256 paidGroup;
        uint256 buyerClaimable;
        uint256 vendorClaimable;
        uint256 treasury;
        uint256 vendorBond;
        uint256 vendorLocked;
        uint256 groupPool;
        uint256 groupLocked;
        uint256 suspended;
        uint256 lost;
        uint256 split;
        uint256 won;
        uint256 inconclusive;
        uint256 groupLost;
        uint256 groupWon;
    }

    uint256 internal constant U = 0.001 ether;
    uint256 internal constant H = 3600;

    function _run(uint256 protectUnits, bool silent, uint8[] memory kinds, uint8[] memory verdicts, bool[] memory reviewed) internal returns (Obs memory o) {
        address arbiter = makeAddr("arbiter");
        address admin = makeAddr("admin");
        address vendor = makeAddr("vendor");
        address buyer = makeAddr("buyer");
        GroupBondBase gb = new GroupBondBase(arbiter, H);
        IGroupBondViews vw = IGroupBondViews(address(gb));
        vm.deal(admin, 100 ether);
        vm.deal(vendor, 100 ether);
        vm.deal(buyer, 100 ether);

        vm.prank(admin);
        gb.createGroup{value: 50 * U}("parity_hub", "Parity Hub", 0, "");
        vm.prank(vendor);
        gb.joinGroup{value: 50 * U}("parity_hub", "parity_shop");
        vm.prank(admin);
        gb.approveVendor(vendor);
        vm.prank(vendor);
        uint256 id = gb.createDeal("Parity item", "1 USD", "", protectUnits * U, 48);
        vm.prank(buyer);
        gb.claimPayment{value: U}(id, "bank ref 123456");
        if (silent) {
            vm.warp(block.timestamp + 24 * H);
            gb.bindByTimeout(id);
        } else {
            vm.prank(vendor);
            gb.respondPayment(id, true, "");
        }
        vm.warp(block.timestamp + 48 * H + 1);
        vm.prank(buyer);
        gb.openDispute{value: U}(id, "nothing was ever sent", "");
        vm.warp(block.timestamp + 48 * H + 1);

        for (uint256 i = 0; i < kinds.length; i++) {
            if (kinds[i] == 1) {
                vm.prank(vendor);
                gb.challengePayout(id, "I never saw this payment", "");
            } else if (kinds[i] == 2) {
                vm.warp(block.timestamp + 168 * H);
                gb.finalizePayout(id);
            } else {
                if (i > 0) vm.warp(block.timestamp + 24 * H + 1);
                vm.prank(arbiter);
                try gb.resolveDispute(id, GroupBondStore.Verdict(verdicts[i]), bytes32("PARITY"), "parity", reviewed[i]) {} catch {
                    o.reverted = true;
                    break;
                }
            }
        }

        GroupBondStore.Deal memory d = vw.getDeal(id);
        GroupBondStore.VendorInfo memory vi = vw.vendorInfo(vendor);
        GroupBondStore.GroupInfo memory gi = vw.groupInfo("parity_hub");
        o.status = uint256(uint8(d.status));
        o.verdict = uint256(uint8(d.verdict));
        o.compensation = d.compensation;
        o.fee = d.fee;
        o.paidVendor = d.paidVendor;
        o.paidGroup = d.paidGroup;
        o.buyerClaimable = gb.claimable(buyer);
        o.vendorClaimable = gb.claimable(vendor);
        o.treasury = gb.treasury();
        o.vendorBond = vi.bond;
        o.vendorLocked = vi.locked;
        o.groupPool = gi.pool;
        o.groupLocked = gi.locked;
        o.suspended = vi.status == GroupBondStore.VendorStatus.SUSPENDED ? 1 : 0;
        o.lost = vi.disputesLost;
        o.split = vi.disputesSplit;
        o.won = vi.disputesWon;
        o.inconclusive = vi.inconclusive;
        o.groupLost = gi.disputesLost;
        o.groupWon = gi.disputesWon;
    }
}
