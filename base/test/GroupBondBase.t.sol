// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/GroupBondBase.sol";

contract GroupBondBaseTest is Test {
    GroupBondBase gb;
    IGroupBondViews vw;
    address owner = makeAddr("owner");
    address arbiter = makeAddr("arbiter");
    address admin = makeAddr("admin");
    address vendor = makeAddr("vendor");
    address buyer = makeAddr("buyer");
    address other = makeAddr("other");
    address stranger = makeAddr("stranger");
    uint256 constant U = 0.001 ether;
    uint256 constant H = 3600;

    function setUp() public {
        vm.prank(owner);
        gb = new GroupBondBase(arbiter, H);
        vw = IGroupBondViews(address(gb));
        address[5] memory who = [admin, vendor, buyer, other, stranger];
        for (uint256 i = 0; i < who.length; i++) vm.deal(who[i], 10 ether);
    }

    function _group(uint256 pool) internal {
        vm.prank(admin);
        gb.createGroup{value: pool}("deal_hub", "Deal Hub", 0, "https://t.me/dealhub");
    }

    function _vendor(uint256 bond) internal {
        vm.prank(vendor);
        gb.joinGroup{value: bond}("deal_hub", "shop_one");
        vm.prank(admin);
        gb.approveVendor(vendor);
    }

    function _market() internal {
        _group(20 * U);
        _vendor(10 * U);
    }

    function _deal(uint256 protect) internal returns (uint256 id) {
        vm.prank(vendor);
        id = gb.createDeal("Red handbag", "40 USD", "https://example.com/p/1", protect, 48);
    }

    function _claim(uint256 id, address who) internal {
        vm.prank(who);
        gb.claimPayment{value: U}(id, "bank ref 123456");
    }

    function _bound(uint256 protect) internal returns (uint256 id) {
        _market();
        id = _deal(protect);
        _claim(id, buyer);
        vm.prank(vendor);
        gb.respondPayment(id, true, "");
    }

    function _silentBound(uint256 protect) internal returns (uint256 id) {
        _market();
        id = _deal(protect);
        _claim(id, buyer);
        vm.warp(block.timestamp + 24 * H);
        gb.bindByTimeout(id);
    }

    function _delivered(uint256 protect) internal returns (uint256 id) {
        id = _bound(protect);
        vm.prank(vendor);
        gb.submitDelivery(id, "shipped with tracking", "https://example.com/t/1");
    }

    function _disputed(uint256 protect) internal returns (uint256 id) {
        id = _delivered(protect);
        vm.prank(buyer);
        gb.openDispute{value: U}(id, "parcel never arrived at all", "");
    }

    function _silentDisputed(uint256 protect) internal returns (uint256 id) {
        id = _silentBound(protect);
        vm.warp(block.timestamp + 48 * H + 1);
        vm.prank(buyer);
        gb.openDispute{value: U}(id, "nothing was ever sent", "");
        vm.warp(block.timestamp + 48 * H + 1);
    }

    function _rule(uint256 id, GroupBondBase.Verdict v, bool reviewed) internal {
        vm.prank(arbiter);
        gb.resolveDispute(id, v, bytes32("CONFLICTING_EVIDENCE"), "ok", reviewed);
    }

    function _rv(GroupBondBase.E e) internal {
        vm.expectRevert(abi.encodeWithSelector(GroupBondStore.Err.selector, e));
    }

    function _eq(uint256 a, uint256 b) internal pure {
        assertEq(a, b);
    }

    function _accounting() internal view {
        uint256 total = vw.totalBonds() + vw.totalPools() + gb.totalClaimable() + gb.treasury() + gb.burned() + gb.depositsHeld();
        _eq(address(gb).balance, total);
    }

    function _locks(uint256 id) internal view {
        GroupBondBase.Deal memory d = vw.getDeal(id);
        GroupBondBase.GroupInfo memory g = vw.groupInfo("deal_hub");
        GroupBondBase.VendorInfo memory v = vw.vendorInfo(vendor);
        bool live = d.status != GroupBondBase.Status.COMPLETED && d.status != GroupBondBase.Status.RESOLVED
            && d.status != GroupBondBase.Status.CANCELLED && d.status != GroupBondBase.Status.EXPIRED;
        _eq(g.locked, live ? d.groupLock : 0);
        _eq(v.locked, live ? d.vendorLock : 0);
    }

    function test_create_group_and_validation() public {
        _rv(GroupBondBase.E.InvalidSlug);
        vm.prank(admin);
        gb.createGroup{value: 20 * U}("Bad Slug", "Deal Hub", 0, "");
        _rv(GroupBondBase.E.PoolBelowMinimum);
        vm.prank(admin);
        gb.createGroup{value: U}("deal_hub", "Deal Hub", 0, "");
        _rv(GroupBondBase.E.InvalidPlatform);
        vm.prank(admin);
        gb.createGroup{value: 20 * U}("deal_hub", "Deal Hub", 9, "");
        _rv(GroupBondBase.E.BadUrl);
        vm.prank(admin);
        gb.createGroup{value: 20 * U}("deal_hub", "Deal Hub", 0, "http://t.me/x");
        _group(20 * U);
        GroupBondBase.GroupInfo memory g = vw.groupInfo("deal_hub");
        assertEq(g.admin, admin);
        _eq(g.pool, 20 * U);
        _rv(GroupBondBase.E.SlugTaken);
        vm.prank(other);
        gb.createGroup{value: 20 * U}("deal_hub", "Deal Hub", 0, "");
        _rv(GroupBondBase.E.AlreadyAdmin);
        vm.prank(admin);
        gb.createGroup{value: 20 * U}("second_hub", "Second Hub", 0, "");
        _accounting();
    }

    function test_vendor_and_admin_roles_are_exclusive() public {
        _group(20 * U);
        _rv(GroupBondBase.E.AdminCannotSell);
        vm.prank(admin);
        gb.joinGroup{value: 5 * U}("deal_hub", "admin_shop");
        vm.prank(vendor);
        gb.joinGroup{value: 5 * U}("deal_hub", "shop_one");
        _rv(GroupBondBase.E.AlreadyVendor);
        vm.prank(vendor);
        gb.createGroup{value: 20 * U}("vendor_hub", "Vendor Hub", 0, "");
        _rv(GroupBondBase.E.HandleTaken);
        vm.prank(other);
        gb.joinGroup{value: 5 * U}("deal_hub", "shop_one");
    }

    function test_join_pending_until_approved() public {
        _group(20 * U);
        vm.prank(vendor);
        gb.joinGroup{value: 10 * U}("deal_hub", "shop_one");
        _eq(uint8(vw.vendorInfo(vendor).status), uint8(GroupBondBase.VendorStatus.PENDING));
        _rv(GroupBondBase.E.VendorIsNotApproved);
        vm.prank(vendor);
        gb.createDeal("Red handbag", "40 USD", "", 2 * U, 48);
        _rv(GroupBondBase.E.NotAGroupAdmin);
        vm.prank(other);
        gb.approveVendor(vendor);
        vm.prank(admin);
        gb.approveVendor(vendor);
        _eq(vw.groupInfo("deal_hub").vendorsApproved, 1);
        _eq(vw.getProtection(vendor), 15 * U);
        assertTrue(vw.isProtected(vendor, 15 * U));
        assertFalse(vw.isProtected(vendor, 16 * U));
        _accounting();
    }

    function test_other_group_admin_cannot_approve() public {
        _group(20 * U);
        vm.prank(other);
        gb.createGroup{value: 20 * U}("other_hub", "Other Hub", 1, "");
        vm.prank(vendor);
        gb.joinGroup{value: 10 * U}("deal_hub", "shop_one");
        _rv(GroupBondBase.E.VendorIsNotInYourGroup);
        vm.prank(other);
        gb.approveVendor(vendor);
    }

    function test_create_locks_both_sides() public {
        _market();
        uint256 id = _deal(4 * U);
        GroupBondBase.Deal memory d = vw.getDeal(id);
        _eq(d.vendorLock, 2 * U);
        _eq(d.groupLock, 2400000000000000);
        _eq(vw.vendorInfo(vendor).locked, 2 * U);
        _eq(vw.groupInfo("deal_hub").locked, 2400000000000000);
        _rv(GroupBondBase.E.ProtectAboveLevelCap);
        vm.prank(vendor);
        gb.createDeal("Big handbag", "40 USD", "", 16 * U, 48);
        _accounting();
    }

    function test_group_capacity_limits_deals() public {
        _group(10 * U);
        _vendor(30 * U);
        vm.prank(vendor);
        gb.createDeal("Red handbag", "40 USD", "", 10 * U, 48);
        _rv(GroupBondBase.E.NotEnoughFreeGroupPool);
        vm.prank(vendor);
        gb.createDeal("Blue handbag", "40 USD", "", 10 * U, 48);
    }

    function test_cancel_and_expire_release_locks() public {
        _market();
        uint256 a = _deal(4 * U);
        vm.prank(vendor);
        gb.cancelDeal(a);
        _locks(a);
        uint256 b = _deal(4 * U);
        _rv(GroupBondBase.E.OfferHasNotExpired);
        gb.expireOffer(b);
        vm.warp(block.timestamp + 72 * H + 1);
        gb.expireOffer(b);
        _locks(b);
        _eq(vw.groupInfo("deal_hub").activeDeals, 0);
    }

    function test_happy_path() public {
        uint256 id = _delivered(4 * U);
        vm.prank(buyer);
        gb.confirmDelivery(id);
        _eq(uint8(vw.getDeal(id).status), uint8(GroupBondBase.Status.COMPLETED));
        _eq(gb.claimable(buyer), U);
        _eq(vw.vendorInfo(vendor).completedVerified, 1);
        _eq(vw.groupInfo("deal_hub").completed, 1);
        _locks(id);
        _accounting();
    }

    function test_reject_burns_deposit_and_blocks_repeat() public {
        _market();
        uint256 id = _deal(4 * U);
        _claim(id, buyer);
        vm.prank(vendor);
        gb.respondPayment(id, false, "no money received");
        _eq(gb.burned(), U);
        _eq(gb.treasury(), 0);
        _eq(gb.claimable(vendor), 0);
        _rv(GroupBondBase.E.ClaimWasRejected);
        vm.prank(buyer);
        gb.claimPayment{value: U}(id, "bank ref 654321");
        _claim(id, other);
        _eq(vw.vendorInfo(vendor).rejectedClaims, 1);
        _accounting();
    }

    function test_claim_rules() public {
        _market();
        uint256 id = _deal(4 * U);
        _rv(GroupBondBase.E.WrongDeposit);
        vm.prank(buyer);
        gb.claimPayment{value: 2 * U}(id, "bank ref 123456");
        _rv(GroupBondBase.E.VendorCannotBuyOwnDeal);
        vm.prank(vendor);
        gb.claimPayment{value: U}(id, "bank ref 123456");
        _rv(GroupBondBase.E.AdminCannotBuyInOwnGroup);
        vm.prank(admin);
        gb.claimPayment{value: U}(id, "bank ref 123456");
        _rv(GroupBondBase.E.PaymentRefLength);
        vm.prank(buyer);
        gb.claimPayment{value: U}(id, "abc");
    }

    function test_timeout_binding() public {
        _market();
        uint256 id = _deal(4 * U);
        _claim(id, buyer);
        _rv(GroupBondBase.E.VendorStillHasTime);
        gb.bindByTimeout(id);
        vm.warp(block.timestamp + 24 * H);
        gb.bindByTimeout(id);
        _eq(vw.getDeal(id).boundBy, 2);
    }

    function test_auto_finalize_and_lapse() public {
        uint256 id = _delivered(4 * U);
        _rv(GroupBondBase.E.ReviewWindowStillOpen);
        gb.finalizeDeal(id);
        vm.warp(block.timestamp + 72 * H + 1);
        gb.finalizeDeal(id);
        _eq(vw.vendorInfo(vendor).completedAuto, 1);
        _eq(gb.claimable(buyer), U);
        _accounting();
        vm.prank(vendor);
        uint256 id2 = gb.createDeal("Blue handbag", "40 USD", "", 2 * U, 24);
        _claim(id2, other);
        vm.prank(vendor);
        gb.respondPayment(id2, true, "");
        vm.warp(block.timestamp + 24 * H + 72 * H + 1);
        gb.finalizeDeal(id2);
        _eq(vw.vendorInfo(vendor).lapsed, 1);
        _eq(uint8(vw.getDeal(id2).status), uint8(GroupBondBase.Status.EXPIRED));
        _accounting();
    }

    function test_buyer_wins_vendor_pays_first_then_group() public {
        uint256 id = _disputed(4 * U);
        vm.warp(block.timestamp + 48 * H + 1);
        _rule(id, GroupBondBase.Verdict.BUYER_WINS, true);
        GroupBondBase.Deal memory d = vw.getDeal(id);
        _eq(d.compensation, 4 * U);
        _eq(d.fee, 200000000000000);
        _eq(d.paidVendor, 2 * U);
        _eq(d.paidGroup, 2200000000000000);
        _eq(vw.vendorInfo(vendor).bond, 8 * U);
        _eq(vw.groupInfo("deal_hub").pool, 20 * U - 2200000000000000);
        _eq(gb.claimable(buyer), 6 * U);
        _locks(id);
        _accounting();
    }

    function test_buyer_win_suspends_vendor_and_counts_for_group() public {
        uint256 id = _disputed(4 * U);
        vm.warp(block.timestamp + 48 * H + 1);
        _rule(id, GroupBondBase.Verdict.BUYER_WINS, true);
        _eq(uint8(vw.vendorInfo(vendor).status), uint8(GroupBondBase.VendorStatus.SUSPENDED));
        _eq(vw.groupInfo("deal_hub").vendorsApproved, 0);
        _eq(vw.groupInfo("deal_hub").disputesLost, 1);
        _eq(vw.getProtection(vendor), 0);
        _rv(GroupBondBase.E.VendorIsNotApproved);
        vm.prank(vendor);
        gb.createDeal("Blue handbag", "40 USD", "", 2 * U, 24);
    }

    function test_seller_wins_gets_deposits_back() public {
        uint256 id = _disputed(4 * U);
        vm.warp(block.timestamp + 48 * H + 1);
        _rule(id, GroupBondBase.Verdict.SELLER_WINS, false);
        _eq(gb.claimable(vendor), 2 * U);
        _eq(gb.claimable(buyer), 0);
        _eq(vw.getDeal(id).compensation, 0);
        _eq(vw.vendorInfo(vendor).disputesWon, 1);
        _accounting();
    }

    function test_split_pays_half_from_vendor_only() public {
        uint256 id = _disputed(4 * U);
        vm.warp(block.timestamp + 48 * H + 1);
        _rule(id, GroupBondBase.Verdict.SPLIT, true);
        GroupBondBase.Deal memory d = vw.getDeal(id);
        _eq(d.compensation, 2 * U);
        _eq(d.paidGroup, 100000000000000);
        _accounting();
    }

    function test_group_lock_always_covers_largest_payout() public {
        _group(10 * U);
        _vendor(30 * U);
        vm.prank(vendor);
        uint256 id = gb.createDeal("Red handbag", "40 USD", "", 10 * U, 48);
        _claim(id, buyer);
        vm.prank(vendor);
        gb.respondPayment(id, true, "");
        vm.prank(vendor);
        gb.submitDelivery(id, "shipped with tracking", "");
        vm.prank(buyer);
        gb.openDispute{value: U}(id, "parcel never arrived at all", "");
        vm.warp(block.timestamp + 48 * H + 1);
        _rule(id, GroupBondBase.Verdict.BUYER_WINS, true);
        GroupBondBase.Deal memory d = vw.getDeal(id);
        _eq(d.paidVendor, 5 * U);
        _eq(d.paidGroup, 5500000000000000);
        assertLe(d.paidGroup, d.groupLock);
        _accounting();
    }

    function test_insufficient_reopens_then_inconclusive() public {
        uint256 id = _disputed(4 * U);
        vm.warp(block.timestamp + 48 * H + 1);
        _rule(id, GroupBondBase.Verdict.INSUFFICIENT_EVIDENCE, false);
        _eq(uint8(vw.getDeal(id).status), uint8(GroupBondBase.Status.REOPENED));
        vm.warp(block.timestamp + 24 * H + 1);
        _rule(id, GroupBondBase.Verdict.INSUFFICIENT_EVIDENCE, false);
        _eq(uint8(vw.getDeal(id).status), uint8(GroupBondBase.Status.RESOLVED));
        _eq(vw.vendorInfo(vendor).inconclusive, 1);
        _eq(gb.claimable(buyer), 2 * U);
        _locks(id);
        _accounting();
    }

    function test_stalled_dispute_closes_without_payout() public {
        uint256 id = _disputed(4 * U);
        vm.warp(block.timestamp + 48 * H + 1);
        _rv(GroupBondBase.E.ArbiterStillHasTime);
        gb.closeStalledDispute(id);
        vm.warp(block.timestamp + 168 * H + 1);
        gb.closeStalledDispute(id);
        _eq(vw.getDeal(id).compensation, 0);
        _eq(gb.claimable(buyer), 2 * U);
        _locks(id);
        _accounting();
    }

    function test_dispute_guards() public {
        uint256 id = _delivered(4 * U);
        _rv(GroupBondBase.E.OnlyBuyer);
        vm.prank(stranger);
        gb.openDispute{value: U}(id, "parcel never arrived at all", "");
        _rv(GroupBondBase.E.WrongDeposit);
        vm.prank(buyer);
        gb.openDispute{value: 2 * U}(id, "parcel never arrived at all", "");
        _rv(GroupBondBase.E.ClaimLength);
        vm.prank(buyer);
        gb.openDispute{value: U}(id, "short", "");
        _rv(GroupBondBase.E.BadUrl);
        vm.prank(buyer);
        gb.openDispute{value: U}(id, "parcel never arrived at all", "http://x.example.com/a");
        vm.warp(block.timestamp + 72 * H + 1);
        _rv(GroupBondBase.E.NotDisputableNow);
        vm.prank(buyer);
        gb.openDispute{value: U}(id, "parcel never arrived at all", "");
    }

    function test_only_arbiter_resolves_and_only_after_window() public {
        uint256 id = _disputed(4 * U);
        _rv(GroupBondBase.E.OnlyArbiter);
        vm.prank(stranger);
        gb.resolveDispute(id, GroupBondBase.Verdict.SPLIT, bytes32("X"), "x", true);
        _rv(GroupBondBase.E.EvidenceWindowOpen);
        vm.prank(arbiter);
        gb.resolveDispute(id, GroupBondBase.Verdict.SPLIT, bytes32("X"), "x", true);
    }

    function test_evidence_limit_and_reopen_bonus() public {
        uint256 id = _disputed(4 * U);
        vm.startPrank(buyer);
        gb.submitEvidence(id, "second piece of proof", "");
        gb.submitEvidence(id, "third piece of proof", "");
        _rv(GroupBondBase.E.EvidenceLimit);
        gb.submitEvidence(id, "fourth piece of proof", "");
        vm.stopPrank();
        vm.warp(block.timestamp + 48 * H + 1);
        _rule(id, GroupBondBase.Verdict.INSUFFICIENT_EVIDENCE, false);
        vm.startPrank(buyer);
        gb.submitEvidence(id, "fourth piece of proof", "");
        gb.submitEvidence(id, "fifth piece of proof", "");
        _rv(GroupBondBase.E.EvidenceLimit);
        gb.submitEvidence(id, "sixth piece of proof", "");
        vm.stopPrank();
    }

    function test_withdraw_limited_by_lock() public {
        _market();
        _deal(4 * U);
        _rv(GroupBondBase.E.AmountExceedsFreeBond);
        vm.prank(vendor);
        gb.withdrawBond(9 * U);
        vm.prank(vendor);
        gb.withdrawBond(8 * U);
        _rv(GroupBondBase.E.AmountExceedsFreePool);
        vm.prank(admin);
        gb.withdrawPool(18 * U);
        vm.prank(admin);
        gb.withdrawPool(17 * U);
        _accounting();
        vm.prank(vendor);
        gb.claim();
        _eq(gb.claimable(vendor), 0);
        _accounting();
    }

    function test_remove_vendor_needs_no_active_deals_and_is_final() public {
        _market();
        uint256 id = _deal(4 * U);
        _rv(GroupBondBase.E.VendorHasActiveDeals);
        vm.prank(admin);
        gb.removeVendor(vendor);
        vm.prank(vendor);
        gb.cancelDeal(id);
        vm.prank(admin);
        gb.removeVendor(vendor);
        _eq(vw.groupInfo("deal_hub").vendorsApproved, 0);
        _rv(GroupBondBase.E.VendorCannotBeApprovedNow);
        vm.prank(admin);
        gb.approveVendor(vendor);
        _rv(GroupBondBase.E.AlreadyRemoved);
        vm.prank(vendor);
        gb.leaveGroup();
    }

    function test_silent_bound_buyer_win_is_delayed_and_capped() public {
        uint256 id = _silentDisputed(4 * U);
        _rule(id, GroupBondBase.Verdict.BUYER_WINS, true);
        GroupBondBase.Deal memory d = vw.getDeal(id);
        _eq(uint8(d.status), uint8(GroupBondBase.Status.PAYOUT_PENDING));
        _eq(d.pendingComp, U);
        _eq(gb.claimable(buyer), 0);
        _rv(GroupBondBase.E.PayoutIsStillLocked);
        gb.finalizePayout(id);
        vm.warp(block.timestamp + 168 * H);
        gb.finalizePayout(id);
        d = vw.getDeal(id);
        _eq(d.compensation, U);
        _eq(d.paidGroup, 0);
        _eq(gb.claimable(buyer), 3 * U);
        _locks(id);
        _accounting();
    }

    function test_silent_win_without_review_flag_is_downgraded() public {
        uint256 id = _silentDisputed(4 * U);
        _rule(id, GroupBondBase.Verdict.BUYER_WINS, false);
        GroupBondBase.Deal memory d = vw.getDeal(id);
        _eq(uint8(d.status), uint8(GroupBondBase.Status.REOPENED));
        _eq(uint8(d.verdict), uint8(GroupBondBase.Verdict.INSUFFICIENT_EVIDENCE));
    }

    function test_vendor_can_challenge_pending_payout() public {
        uint256 id = _silentDisputed(4 * U);
        _rule(id, GroupBondBase.Verdict.BUYER_WINS, true);
        _rv(GroupBondBase.E.OnlyVendor);
        vm.prank(buyer);
        gb.challengePayout(id, "I never saw this payment", "");
        vm.prank(vendor);
        gb.challengePayout(id, "My bank shows no incoming transfer", "https://example.com/stmt");
        _eq(uint8(vw.getDeal(id).status), uint8(GroupBondBase.Status.CHALLENGED));
        vm.warp(block.timestamp + 24 * H + 1);
        _rule(id, GroupBondBase.Verdict.SELLER_WINS, false);
        _eq(gb.claimable(vendor), 2 * U);
        _eq(gb.claimable(buyer), 0);
        _locks(id);
        _accounting();
    }

    function test_challenge_window_closes() public {
        uint256 id = _silentDisputed(4 * U);
        _rule(id, GroupBondBase.Verdict.BUYER_WINS, true);
        vm.warp(block.timestamp + 168 * H);
        _rv(GroupBondBase.E.ChallengeWindowClosed);
        vm.prank(vendor);
        gb.challengePayout(id, "too late to object", "");
    }

    function test_challenged_ruling_pays_immediately_and_stays_capped() public {
        uint256 id = _silentDisputed(4 * U);
        _rule(id, GroupBondBase.Verdict.BUYER_WINS, true);
        vm.prank(vendor);
        gb.challengePayout(id, "My bank shows no incoming transfer", "");
        vm.warp(block.timestamp + 24 * H + 1);
        _rule(id, GroupBondBase.Verdict.BUYER_WINS, true);
        GroupBondBase.Deal memory d = vw.getDeal(id);
        _eq(uint8(d.status), uint8(GroupBondBase.Status.RESOLVED));
        _eq(d.compensation, U);
        _accounting();
    }

    function test_pair_credit_limit_and_unique_buyers() public {
        _group(50 * U);
        _vendor(50 * U);
        for (uint256 i = 0; i < 5; i++) {
            address b = i % 2 == 0 ? buyer : other;
            uint256 id = _deal(2 * U);
            _claim(id, b);
            vm.prank(vendor);
            gb.respondPayment(id, true, "");
            vm.prank(vendor);
            gb.submitDelivery(id, "shipped ok", "");
            vm.prank(b);
            gb.confirmDelivery(id);
        }
        GroupBondBase.VendorInfo memory v = vw.vendorInfo(vendor);
        _eq(v.uniqueBuyers, 2);
        _eq(v.completedVerified, 5);
        vm.warp(block.timestamp + 340 * H);
        assertLt(vw.vendorInfo(vendor).uniqueBuyers, 5);
    }

    function test_arbiter_and_owner_are_fixed_at_deploy() public {
        assertEq(gb.arbiter(), arbiter);
        assertEq(gb.owner(), owner);
        _disputed(4 * U);
        vm.warp(block.timestamp + 48 * H + 1);
        _rv(GroupBondBase.E.OnlyArbiter);
        vm.prank(stranger);
        gb.resolveDispute(0, GroupBondBase.Verdict.SPLIT, bytes32("X"), "x", true);
    }

    function test_owner_collects_fees() public {
        uint256 id = _disputed(4 * U);
        vm.warp(block.timestamp + 48 * H + 1);
        _rule(id, GroupBondBase.Verdict.BUYER_WINS, true);
        _eq(gb.treasury(), 200000000000000);
        _rv(GroupBondBase.E.OnlyOwner);
        vm.prank(stranger);
        gb.collectFees();
        vm.prank(owner);
        gb.collectFees();
        vm.prank(owner);
        gb.claim();
        _eq(owner.balance, 200000000000000);
        _accounting();
    }

    function test_bad_unit_rejected() public {
        _rv(GroupBondBase.E.BadUnit);
        new GroupBondBase(arbiter, 0);
        _rv(GroupBondBase.E.ArbiterRequired);
        new GroupBondBase(address(0), H);
    }
}
