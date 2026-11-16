// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract GroupBondBase {
    enum Status { OPEN, PAYMENT_CLAIMED, ACTIVE, DELIVERED, COMPLETED, DISPUTED, REOPENED, RESOLVED, CANCELLED, EXPIRED, PAYOUT_PENDING, CHALLENGED }
    enum Verdict { NONE, BUYER_WINS, SELLER_WINS, SPLIT, INSUFFICIENT_EVIDENCE }
    enum E { Reentrancy, OnlyOwner, ArbiterRequired, BadUnit, NothingProposed, ChangeIsStillLocked, ZeroAddress, NotARegisteredVendor, NotAGroupAdmin, UnknownDeal, InvalidSlug, SlugTaken, AlreadyAdmin, AlreadyVendor, InvalidName, InvalidPlatform, BadUrl, PoolBelowMinimum, NoValue, AmountMustBePositive, AmountExceedsFreePool, UnknownGroup, InvalidHandle, AlreadyRegistered, AdminCannotSell, HandleTaken, BondBelowMinimum, AmountExceedsFreeBond, VendorIsNotInYourGroup, VendorCannotBeApprovedNow, VendorIsNotApproved, AlreadyRemoved, VendorHasActiveDeals, ItemLength, PriceLength, ProtectBelowMinimum, ProtectAboveLevelCap, DeliveryHours, NotEnoughFreeVendorBond, NotEnoughFreeGroupPool, OnlyVendor, DealIsNotOpen, OfferHasNotExpired, DealNotOpen, OfferExpired, VendorCannotBuyOwnDeal, AdminCannotBuyInOwnGroup, WrongDeposit, PaymentRefLength, ClaimWasRejected, NoPaymentClaimToAnswer, ReasonLength, NoPaymentClaimPending, VendorStillHasTime, DealIsNotActive, DeliveryTextLength, OnlyBuyer, DeliveryNotClaimed, ReviewWindowStillOpen, DisputeWindowStillOpen, NotDisputableNow, ClaimLength, NotInDispute, WindowClosed, OnlyParties, EvidenceLimit, TextLength, OnlyArbiter, EvidenceWindowOpen, VerdictRequired, ReasonTooLong, NoPendingPayout, ChallengeWindowClosed, PayoutIsStillLocked, ArbiterStillHasTime, PaymentEvidenceNotReviewed, PayoutExceedsLocks, NothingToClaim, TransferFailed, NoFees, DealCannotBeFinalized }
    error Err(E code);
    enum VendorStatus { NONE, PENDING, APPROVED, SUSPENDED, REMOVED }

    struct Group {
        string slug;
        address admin;
        string name;
        uint8 platform;
        string inviteUrl;
        uint256 pool;
        uint256 locked;
        uint256 compensated;
        uint64 createdAt;
        uint32 vendorsTotal;
        uint32 vendorsApproved;
        uint32 dealsBound;
        uint32 completed;
        uint32 disputesLost;
        uint32 disputesWon;
        uint32 disputesSplit;
        uint32 inconclusive;
        uint32 activeDeals;
        bool exists;
    }

    struct GroupInfo {
        string slug;
        address admin;
        string name;
        uint8 platform;
        string inviteUrl;
        uint256 pool;
        uint256 locked;
        uint256 compensated;
        uint64 createdAt;
        uint32 vendorsTotal;
        uint32 vendorsApproved;
        uint32 dealsBound;
        uint32 completed;
        uint32 disputesLost;
        uint32 disputesWon;
        uint32 disputesSplit;
        uint32 inconclusive;
        uint32 activeDeals;
    }

    struct Vendor {
        bytes32 groupKey;
        string handle;
        VendorStatus status;
        uint256 bond;
        uint256 locked;
        uint256 compensated;
        uint64 createdAt;
        uint64 approvedAt;
        uint32 dealsBound;
        uint32 completedVerified;
        uint32 completedAuto;
        uint32 disputesLost;
        uint32 disputesSplit;
        uint32 disputesWon;
        uint32 inconclusive;
        uint32 rejectedClaims;
        uint32 lapsed;
        uint32 activeDeals;
        uint32 uniqueBuyers;
        bool exists;
    }

    struct VendorInfo {
        address owner;
        string groupSlug;
        string handle;
        VendorStatus status;
        uint256 bond;
        uint256 locked;
        uint256 available;
        uint256 compensated;
        uint64 createdAt;
        uint32 dealsBound;
        uint32 completedVerified;
        uint32 completedAuto;
        uint32 disputesLost;
        uint32 disputesSplit;
        uint32 disputesWon;
        uint32 inconclusive;
        uint32 rejectedClaims;
        uint32 lapsed;
        uint32 activeDeals;
        uint32 uniqueBuyers;
    }

    struct Deal {
        uint256 id;
        bytes32 groupKey;
        address seller;
        address buyer;
        string item;
        string priceText;
        string listingUrl;
        uint256 protect;
        uint256 vendorLock;
        uint256 groupLock;
        uint256 deliverySecs;
        Status status;
        uint64 createdAt;
        uint64 offerExpires;
        uint64 claimedAt;
        string paymentRef;
        uint64 boundAt;
        uint8 boundBy;
        uint64 deliveryDeadline;
        uint64 deliveredAt;
        string deliveryText;
        string deliveryUrl;
        uint32 rejections;
        string rejectReason;
        uint256 deposit;
        uint64 evidenceDeadline;
        bool reopened;
        uint8 evBuyer;
        uint8 evSeller;
        Verdict verdict;
        bytes32 reasonCode;
        string reason;
        uint256 compensation;
        uint256 fee;
        uint256 paidVendor;
        uint256 paidGroup;
        uint64 resolvedAt;
        bool paymentEvidenceReviewed;
        uint256 claimDeposit;
        uint256 pendingComp;
        uint64 unlockAt;
        bool challenged;
        bool confirmed;
        uint64 disputeOpenedAt;
    }

    struct Evidence {
        bool byBuyer;
        string text;
        string url;
        bytes32 digest;
        uint64 at;
    }

    uint256 public constant MIN_POOL = 0.01 ether;
    uint256 public constant MIN_BOND = 0.003 ether;
    uint256 public constant VERIFIED_BOND = 0.01 ether;
    uint256 public constant PREMIUM_BOND = 0.03 ether;
    uint256 public constant MAX_PROTECT_STARTER = 0.004 ether;
    uint256 public constant MAX_PROTECT_VERIFIED = 0.015 ether;
    uint256 public constant MAX_PROTECT_PREMIUM = 0.04 ether;
    uint256 public constant MIN_PROTECT = 0.001 ether;
    uint256 public constant DISPUTE_DEPOSIT = 0.001 ether;
    uint256 public constant CLAIM_DEPOSIT = 0.001 ether;
    uint256 public constant VENDOR_BPS = 5000;
    uint256 public constant GROUP_BPS = 6000;
    uint256 public constant FEE_BPS = 500;
    uint256 public constant TIMEOUT_CAP_BPS = 2500;
    uint256 constant TRUSTED_MIN_COMPLETED = 5;
    uint256 constant TRUSTED_MIN_VERIFIED = 3;
    uint256 constant TRUSTED_MIN_UNIQUE = 5;
    uint256 public constant PAIR_CREDIT_LIMIT = 3;
    uint256 public constant EVIDENCE_REOPEN_BONUS = 2;
    uint256 public constant MAX_EVIDENCE_PER_SIDE = 3;
    uint256 public constant MAX_DELIVERY_HOURS = 720;

    uint256 public immutable unit;
    uint256 public immutable offerWindow;
    uint256 public immutable confirmWindow;
    uint256 public immutable reviewWindow;
    uint256 public immutable evidenceWindow;
    uint256 public immutable reopenWindow;
    uint256 public immutable arbiterTimeout;
    uint256 public immutable payoutDelay;
    uint256 public immutable trustedMinAge;

    address public immutable owner;
    address public immutable arbiter;
    uint256 public treasury;
    uint256 public burned;
    uint256 public depositsHeld;
    uint256 public totalClaimable;
    uint256 public dealCount;

    mapping(bytes32 => Group) private groups;
    mapping(address => bytes32) private groupOfAdmin;
    bytes32[] private groupList;
    mapping(address => Vendor) private vendors;
    mapping(bytes32 => address) private handleOwners;
    address[] private vendorList;
    mapping(uint256 => Deal) private deals;
    mapping(uint256 => Evidence[]) private evidences;
    mapping(address => uint256) public claimable;
    mapping(bytes32 => uint256) public pairCounts;
    mapping(bytes32 => bool) private rejectedClaim;

    uint256 private lockFlag = 1;

    event GroupCreated(bytes32 indexed key, string slug, address indexed admin, uint256 pool);
    event PoolChanged(bytes32 indexed key, uint256 pool);
    event VendorJoined(address indexed vendor, bytes32 indexed groupKey, string handle, uint256 bond);
    event VendorStatusChanged(address indexed vendor, VendorStatus status);
    event BondChanged(address indexed vendor, uint256 bond);
    event DealCreated(uint256 indexed id, address indexed seller, uint256 protect);
    event DealStatus(uint256 indexed id, Status status);
    event EvidenceAdded(uint256 indexed id, bool byBuyer, bytes32 digest);
    event PayoutPending(uint256 indexed id, uint256 amount, uint64 unlockAt);
    event PayoutChallenged(uint256 indexed id);
    event Resolved(uint256 indexed id, Verdict verdict, bytes32 reasonCode, uint256 compensation, bool paymentEvidenceReviewed);
    event Reopened(uint256 indexed id, uint64 evidenceDeadline);
    event Claimed(address indexed who, uint256 amount);

    modifier nonReentrant() {
        if (!(lockFlag == 1)) _f(E.Reentrancy);
        lockFlag = 2;
        _;
        lockFlag = 1;
    }

    modifier onlyOwner() {
        if (!(msg.sender == owner)) _f(E.OnlyOwner);
        _;
    }

    constructor(address arbiter_, uint256 unit_) {
        if (!(arbiter_ != address(0))) _f(E.ArbiterRequired);
        if (!(unit_ >= 1 && unit_ <= 86400)) _f(E.BadUnit);
        owner = msg.sender;
        arbiter = arbiter_;
        unit = unit_;
        offerWindow = 72 * unit_;
        confirmWindow = 24 * unit_;
        reviewWindow = 72 * unit_;
        evidenceWindow = 48 * unit_;
        reopenWindow = 24 * unit_;
        arbiterTimeout = 168 * unit_;
        payoutDelay = 168 * unit_;
        trustedMinAge = 336 * unit_;
    }

    function _f(E e) private pure {
        revert Err(e);
    }

    function _level(uint256 bond) internal pure returns (uint8) {
        if (bond >= PREMIUM_BOND) return 2;
        if (bond >= VERIFIED_BOND) return 1;
        return 0;
    }

    function _maxProtect(uint8 level) internal pure returns (uint256) {
        if (level == 2) return MAX_PROTECT_PREMIUM;
        if (level == 1) return MAX_PROTECT_VERIFIED;
        return MAX_PROTECT_STARTER;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _available(Vendor storage v, Group storage g) internal view returns (uint256) {
        if (v.bond <= v.locked || g.pool <= g.locked) return 0;
        uint256 vfree = v.bond - v.locked;
        uint256 gfree = g.pool - g.locked;
        return _min(_maxProtect(_level(v.bond)), _min((vfree * 10000) / VENDOR_BPS, (gfree * 10000) / GROUP_BPS));
    }

    function _validKey(string memory h, uint256 lo, uint256 hi, bool allowDot) internal pure returns (bool) {
        bytes memory b = bytes(h);
        if (b.length < lo || b.length > hi) return false;
        for (uint256 i = 0; i < b.length; i++) {
            bytes1 c = b[i];
            bool ok = (c >= 0x61 && c <= 0x7a) || (c >= 0x30 && c <= 0x39) || c == 0x5f || (allowDot && c == 0x2e);
            if (!ok) return false;
        }
        return true;
    }

    function _isAlpha(bytes1 c) internal pure returns (bool) {
        return (c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a);
    }

    function _isDigit(bytes1 c) internal pure returns (bool) {
        return c >= 0x30 && c <= 0x39;
    }

    function _validUrl(string memory u) internal pure returns (bool) {
        bytes memory b = bytes(u);
        if (b.length == 0) return true;
        if (b.length > 300 || b.length < 12) return false;
        bytes memory p = bytes("https://");
        for (uint256 i = 0; i < p.length; i++) {
            if (b[i] != p[i]) return false;
        }
        for (uint256 i = 0; i < b.length; i++) {
            uint8 c = uint8(b[i]);
            if (c <= 0x20 || c >= 0x7f || c == 0x5c) return false;
        }
        uint256 end = b.length;
        for (uint256 i = 8; i < b.length; i++) {
            bytes1 c = b[i];
            if (c == 0x2f || c == 0x3f || c == 0x23) {
                end = i;
                break;
            }
        }
        if (end == 8) return false;
        return _validAuthority(b, 8, end);
    }

    function _validAuthority(bytes memory b, uint256 start, uint256 end) internal pure returns (bool) {
        uint256 hostEnd = end;
        for (uint256 i = start; i < end; i++) {
            bytes1 c = b[i];
            if (c == 0x40 || c == 0x5b || c == 0x5d) return false;
        }
        for (uint256 i = start; i < end; i++) {
            if (b[i] == 0x3a) {
                hostEnd = i;
                break;
            }
        }
        if (hostEnd < end) {
            if (end - hostEnd != 4) return false;
            if (b[hostEnd + 1] != 0x34 || b[hostEnd + 2] != 0x34 || b[hostEnd + 3] != 0x33) return false;
        }
        if (hostEnd == start) return false;
        uint256 labelStart = start;
        uint256 labels = 0;
        for (uint256 i = start; i <= hostEnd; i++) {
            bool atEnd = i == hostEnd;
            if (atEnd || b[i] == 0x2e) {
                if (i == labelStart) return false;
                labels++;
                if (atEnd) {
                    if (i - labelStart < 2) return false;
                    for (uint256 j = labelStart; j < i; j++) {
                        if (!_isAlpha(b[j])) return false;
                    }
                }
                labelStart = i + 1;
            } else if (!(_isAlpha(b[i]) || _isDigit(b[i]) || b[i] == 0x2d)) {
                return false;
            }
        }
        return labels >= 2;
    }

    function _len(string memory s, uint256 lo, uint256 hi) internal pure returns (bool) {
        uint256 n = bytes(s).length;
        return n >= lo && n <= hi;
    }

    function _credit(address who, uint256 amount) internal {
        if (amount == 0) return;
        claimable[who] += amount;
        totalClaimable += amount;
    }

    function _vendor(address who) internal view returns (Vendor storage v) {
        v = vendors[who];
        if (!(v.exists)) _f(E.NotARegisteredVendor);
    }

    function _adminGroup(address who) internal view returns (Group storage g, bytes32 key) {
        key = groupOfAdmin[who];
        if (!(key != bytes32(0))) _f(E.NotAGroupAdmin);
        g = groups[key];
    }

    function _deal(uint256 id) internal view returns (Deal storage d) {
        if (!(id < dealCount)) _f(E.UnknownDeal);
        d = deals[id];
    }

    function _release(Deal storage d, Vendor storage v, Group storage g) internal {
        v.locked -= d.vendorLock;
        g.locked -= d.groupLock;
        v.activeDeals -= 1;
        g.activeDeals -= 1;
    }

    function createGroup(string calldata slug, string calldata name, uint8 platform, string calldata inviteUrl) external payable {
        if (!(_validKey(slug, 3, 30, false))) _f(E.InvalidSlug);
        bytes32 key = keccak256(bytes(slug));
        if (!(!groups[key].exists)) _f(E.SlugTaken);
        if (!(groupOfAdmin[msg.sender] == bytes32(0))) _f(E.AlreadyAdmin);
        if (!(!vendors[msg.sender].exists)) _f(E.AlreadyVendor);
        if (!(_len(name, 3, 60))) _f(E.InvalidName);
        if (!(platform <= 4)) _f(E.InvalidPlatform);
        if (!(_validUrl(inviteUrl))) _f(E.BadUrl);
        if (!(msg.value >= MIN_POOL)) _f(E.PoolBelowMinimum);
        Group storage g = groups[key];
        g.slug = slug;
        g.admin = msg.sender;
        g.name = name;
        g.platform = platform;
        g.inviteUrl = inviteUrl;
        g.pool = msg.value;
        g.createdAt = uint64(block.timestamp);
        g.exists = true;
        groupOfAdmin[msg.sender] = key;
        groupList.push(key);
        emit GroupCreated(key, slug, msg.sender, msg.value);
    }

    function addPool() external payable {
        (Group storage g, bytes32 key) = _adminGroup(msg.sender);
        if (!(msg.value > 0)) _f(E.NoValue);
        g.pool += msg.value;
        emit PoolChanged(key, g.pool);
    }

    function withdrawPool(uint256 amount) external {
        (Group storage g, bytes32 key) = _adminGroup(msg.sender);
        if (!(amount > 0)) _f(E.AmountMustBePositive);
        if (!(amount <= g.pool - g.locked)) _f(E.AmountExceedsFreePool);
        g.pool -= amount;
        _credit(msg.sender, amount);
        emit PoolChanged(key, g.pool);
    }

    function joinGroup(string calldata slug, string calldata handle) external payable {
        bytes32 key = keccak256(bytes(slug));
        Group storage g = groups[key];
        if (!(g.exists)) _f(E.UnknownGroup);
        if (!(_validKey(handle, 3, 30, true))) _f(E.InvalidHandle);
        if (!(!vendors[msg.sender].exists)) _f(E.AlreadyRegistered);
        if (!(groupOfAdmin[msg.sender] == bytes32(0))) _f(E.AdminCannotSell);
        bytes32 hk = keccak256(bytes(handle));
        if (!(handleOwners[hk] == address(0))) _f(E.HandleTaken);
        if (!(msg.value >= MIN_BOND)) _f(E.BondBelowMinimum);
        Vendor storage v = vendors[msg.sender];
        v.groupKey = key;
        v.handle = handle;
        v.status = VendorStatus.PENDING;
        v.bond = msg.value;
        v.createdAt = uint64(block.timestamp);
        v.exists = true;
        handleOwners[hk] = msg.sender;
        vendorList.push(msg.sender);
        g.vendorsTotal += 1;
        emit VendorJoined(msg.sender, key, handle, msg.value);
    }

    function addBond() external payable {
        Vendor storage v = _vendor(msg.sender);
        if (!(msg.value > 0)) _f(E.NoValue);
        v.bond += msg.value;
        emit BondChanged(msg.sender, v.bond);
    }

    function withdrawBond(uint256 amount) external {
        Vendor storage v = _vendor(msg.sender);
        if (!(amount > 0)) _f(E.AmountMustBePositive);
        if (!(amount <= v.bond - v.locked)) _f(E.AmountExceedsFreeBond);
        v.bond -= amount;
        _credit(msg.sender, amount);
        emit BondChanged(msg.sender, v.bond);
    }

    function approveVendor(address who) external {
        (Group storage g, bytes32 key) = _adminGroup(msg.sender);
        Vendor storage v = _vendor(who);
        if (!(v.groupKey == key)) _f(E.VendorIsNotInYourGroup);
        if (!(v.status == VendorStatus.PENDING || v.status == VendorStatus.SUSPENDED)) _f(E.VendorCannotBeApprovedNow);
        v.status = VendorStatus.APPROVED;
        if (v.approvedAt == 0) v.approvedAt = uint64(block.timestamp);
        g.vendorsApproved += 1;
        emit VendorStatusChanged(who, v.status);
    }

    function suspendVendor(address who) external {
        (Group storage g, bytes32 key) = _adminGroup(msg.sender);
        Vendor storage v = _vendor(who);
        if (!(v.groupKey == key)) _f(E.VendorIsNotInYourGroup);
        if (!(v.status == VendorStatus.APPROVED)) _f(E.VendorIsNotApproved);
        v.status = VendorStatus.SUSPENDED;
        g.vendorsApproved -= 1;
        emit VendorStatusChanged(who, v.status);
    }

    function removeVendor(address who) external {
        (Group storage g, bytes32 key) = _adminGroup(msg.sender);
        Vendor storage v = _vendor(who);
        if (!(v.groupKey == key)) _f(E.VendorIsNotInYourGroup);
        _remove(v, g, who);
    }

    function leaveGroup() external {
        Vendor storage v = _vendor(msg.sender);
        _remove(v, groups[v.groupKey], msg.sender);
    }

    function _remove(Vendor storage v, Group storage g, address who) internal {
        if (!(v.status != VendorStatus.REMOVED)) _f(E.AlreadyRemoved);
        if (!(v.activeDeals == 0)) _f(E.VendorHasActiveDeals);
        if (v.status == VendorStatus.APPROVED) g.vendorsApproved -= 1;
        v.status = VendorStatus.REMOVED;
        emit VendorStatusChanged(who, v.status);
    }

    function createDeal(
        string calldata item,
        string calldata priceText,
        string calldata listingUrl,
        uint256 protect,
        uint256 deliveryHours
    ) external returns (uint256 id) {
        Vendor storage v = _vendor(msg.sender);
        if (!(v.status == VendorStatus.APPROVED)) _f(E.VendorIsNotApproved);
        Group storage g = groups[v.groupKey];
        if (!(_len(item, 3, 200))) _f(E.ItemLength);
        if (!(_len(priceText, 1, 80))) _f(E.PriceLength);
        if (!(_validUrl(listingUrl))) _f(E.BadUrl);
        if (!(protect >= MIN_PROTECT)) _f(E.ProtectBelowMinimum);
        if (!(protect <= _maxProtect(_level(v.bond)))) _f(E.ProtectAboveLevelCap);
        if (!(deliveryHours >= 1 && deliveryHours <= MAX_DELIVERY_HOURS)) _f(E.DeliveryHours);
        uint256 vlock = (protect * VENDOR_BPS) / 10000;
        uint256 glock = (protect * GROUP_BPS) / 10000;
        if (!(vlock <= v.bond - v.locked)) _f(E.NotEnoughFreeVendorBond);
        if (!(glock <= g.pool - g.locked)) _f(E.NotEnoughFreeGroupPool);
        id = dealCount++;
        Deal storage d = deals[id];
        d.id = id;
        d.groupKey = v.groupKey;
        d.seller = msg.sender;
        d.item = item;
        d.priceText = priceText;
        d.listingUrl = listingUrl;
        d.protect = protect;
        d.vendorLock = vlock;
        d.groupLock = glock;
        d.deliverySecs = deliveryHours * unit;
        d.status = Status.OPEN;
        d.createdAt = uint64(block.timestamp);
        d.offerExpires = uint64(block.timestamp + offerWindow);
        v.locked += vlock;
        g.locked += glock;
        v.activeDeals += 1;
        g.activeDeals += 1;
        emit DealCreated(id, msg.sender, protect);
        emit DealStatus(id, d.status);
    }

    function cancelDeal(uint256 id) external {
        Deal storage d = _deal(id);
        if (!(msg.sender == d.seller)) _f(E.OnlyVendor);
        if (!(d.status == Status.OPEN)) _f(E.DealIsNotOpen);
        _release(d, vendors[d.seller], groups[d.groupKey]);
        d.status = Status.CANCELLED;
        d.resolvedAt = uint64(block.timestamp);
        emit DealStatus(id, d.status);
    }

    function expireOffer(uint256 id) external {
        Deal storage d = _deal(id);
        if (!(d.status == Status.OPEN)) _f(E.DealIsNotOpen);
        if (!(block.timestamp > d.offerExpires)) _f(E.OfferHasNotExpired);
        _release(d, vendors[d.seller], groups[d.groupKey]);
        d.status = Status.EXPIRED;
        d.resolvedAt = uint64(block.timestamp);
        emit DealStatus(id, d.status);
    }

    function claimPayment(uint256 id, string calldata paymentRef) external payable {
        Deal storage d = _deal(id);
        if (!(d.status == Status.OPEN)) _f(E.DealNotOpen);
        if (!(block.timestamp <= d.offerExpires)) _f(E.OfferExpired);
        if (!(msg.sender != d.seller)) _f(E.VendorCannotBuyOwnDeal);
        if (!(msg.sender != groups[d.groupKey].admin)) _f(E.AdminCannotBuyInOwnGroup);
        if (!(msg.value == CLAIM_DEPOSIT)) _f(E.WrongDeposit);
        if (!(_len(paymentRef, 5, 300))) _f(E.PaymentRefLength);
        if (!(!rejectedClaim[keccak256(abi.encodePacked(id, msg.sender))])) _f(E.ClaimWasRejected);
        d.buyer = msg.sender;
        d.paymentRef = paymentRef;
        d.claimedAt = uint64(block.timestamp);
        d.claimDeposit = msg.value;
        depositsHeld += msg.value;
        d.status = Status.PAYMENT_CLAIMED;
        emit DealStatus(id, d.status);
    }

    function _bind(Deal storage d, uint8 by) internal {
        d.status = Status.ACTIVE;
        d.boundAt = uint64(block.timestamp);
        d.boundBy = by;
        d.deliveryDeadline = uint64(block.timestamp + d.deliverySecs);
        vendors[d.seller].dealsBound += 1;
        groups[d.groupKey].dealsBound += 1;
        emit DealStatus(d.id, d.status);
    }

    function respondPayment(uint256 id, bool accept, string calldata reason) external {
        Deal storage d = _deal(id);
        if (!(msg.sender == d.seller)) _f(E.OnlyVendor);
        if (!(d.status == Status.PAYMENT_CLAIMED)) _f(E.NoPaymentClaimToAnswer);
        if (accept) {
            _bind(d, 1);
            return;
        }
        if (!(_len(reason, 5, 200))) _f(E.ReasonLength);
        vendors[d.seller].rejectedClaims += 1;
        rejectedClaim[keccak256(abi.encodePacked(id, d.buyer))] = true;
        uint256 dep = d.claimDeposit;
        d.claimDeposit = 0;
        depositsHeld -= dep;
        burned += dep;
        d.rejections += 1;
        d.rejectReason = reason;
        d.buyer = address(0);
        d.paymentRef = "";
        d.claimedAt = 0;
        d.status = Status.OPEN;
        d.offerExpires = uint64(block.timestamp + offerWindow);
        emit DealStatus(id, d.status);
    }

    function bindByTimeout(uint256 id) external {
        Deal storage d = _deal(id);
        if (!(d.status == Status.PAYMENT_CLAIMED)) _f(E.NoPaymentClaimPending);
        if (!(block.timestamp >= uint256(d.claimedAt) + confirmWindow)) _f(E.VendorStillHasTime);
        _bind(d, 2);
    }

    function submitDelivery(uint256 id, string calldata text, string calldata url) external {
        Deal storage d = _deal(id);
        if (!(msg.sender == d.seller)) _f(E.OnlyVendor);
        if (!(d.status == Status.ACTIVE)) _f(E.DealIsNotActive);
        if (!(_len(text, 3, 1500))) _f(E.DeliveryTextLength);
        if (!(_validUrl(url))) _f(E.BadUrl);
        d.deliveryText = text;
        d.deliveryUrl = url;
        d.deliveredAt = uint64(block.timestamp);
        d.status = Status.DELIVERED;
        emit DealStatus(id, d.status);
    }

    function _returnClaimDeposit(Deal storage d, bool toSeller) internal {
        uint256 dep = d.claimDeposit;
        if (dep == 0) return;
        d.claimDeposit = 0;
        depositsHeld -= dep;
        _credit(toSeller ? d.seller : d.buyer, dep);
    }

    function _inDispute(Deal storage d) internal view returns (bool) {
        return d.status == Status.DISPUTED || d.status == Status.REOPENED || d.status == Status.CHALLENGED;
    }

    function _creditCompletion(Deal storage d, Vendor storage v, bool verified) internal {
        bytes32 pair = keccak256(abi.encodePacked(d.seller, d.buyer));
        uint256 n = pairCounts[pair];
        if (d.protect >= MIN_PROTECT && n < PAIR_CREDIT_LIMIT) {
            pairCounts[pair] = n + 1;
            if (n == 0) v.uniqueBuyers += 1;
            if (verified) v.completedVerified += 1;
            else v.completedAuto += 1;
        }
    }

    function confirmDelivery(uint256 id) external {
        Deal storage d = _deal(id);
        if (!(msg.sender == d.buyer)) _f(E.OnlyBuyer);
        if (!(d.status == Status.DELIVERED)) _f(E.DeliveryNotClaimed);
        Vendor storage v = vendors[d.seller];
        Group storage g = groups[d.groupKey];
        _release(d, v, g);
        _creditCompletion(d, v, true);
        g.completed += 1;
        _returnClaimDeposit(d, false);
        d.confirmed = true;
        d.status = Status.COMPLETED;
        d.resolvedAt = uint64(block.timestamp);
        emit DealStatus(id, d.status);
    }

    function finalizeDeal(uint256 id) external {
        Deal storage d = _deal(id);
        Vendor storage v = vendors[d.seller];
        Group storage g = groups[d.groupKey];
        if (d.status == Status.DELIVERED) {
            if (!(block.timestamp > uint256(d.deliveredAt) + reviewWindow)) _f(E.ReviewWindowStillOpen);
            _release(d, v, g);
            _creditCompletion(d, v, false);
            g.completed += 1;
            _returnClaimDeposit(d, false);
            d.status = Status.COMPLETED;
        } else if (d.status == Status.ACTIVE) {
            if (!(block.timestamp > uint256(d.deliveryDeadline) + reviewWindow)) _f(E.DisputeWindowStillOpen);
            _release(d, v, g);
            v.lapsed += 1;
            _returnClaimDeposit(d, false);
            d.status = Status.EXPIRED;
        } else {
            _f(E.DealCannotBeFinalized);
        }
        d.resolvedAt = uint64(block.timestamp);
        emit DealStatus(id, d.status);
    }

    function _addEvidence(Deal storage d, bool byBuyer, string memory text, string memory url) internal {
        bytes32 digest = keccak256(abi.encodePacked(text, "\n", url));
        evidences[d.id].push(Evidence(byBuyer, text, url, digest, uint64(block.timestamp)));
        if (byBuyer) d.evBuyer += 1;
        else d.evSeller += 1;
        emit EvidenceAdded(d.id, byBuyer, digest);
    }

    function openDispute(uint256 id, string calldata claimText, string calldata url) external payable {
        Deal storage d = _deal(id);
        if (!(msg.sender == d.buyer)) _f(E.OnlyBuyer);
        if (!(msg.value == DISPUTE_DEPOSIT)) _f(E.WrongDeposit);
        bool late = d.status == Status.ACTIVE && block.timestamp > d.deliveryDeadline
            && block.timestamp <= uint256(d.deliveryDeadline) + reviewWindow;
        bool mismatch = d.status == Status.DELIVERED && block.timestamp <= uint256(d.deliveredAt) + reviewWindow;
        if (!(late || mismatch)) _f(E.NotDisputableNow);
        if (!(_len(claimText, 10, 1500))) _f(E.ClaimLength);
        if (!(_validUrl(url))) _f(E.BadUrl);
        d.deposit = msg.value;
        depositsHeld += msg.value;
        d.evidenceDeadline = uint64(block.timestamp + evidenceWindow);
        d.disputeOpenedAt = uint64(block.timestamp);
        d.status = Status.DISPUTED;
        _addEvidence(d, true, claimText, url);
        emit DealStatus(id, d.status);
    }

    function submitEvidence(uint256 id, string calldata text, string calldata url) external {
        Deal storage d = _deal(id);
        if (!(_inDispute(d))) _f(E.NotInDispute);
        if (!(block.timestamp <= d.evidenceDeadline)) _f(E.WindowClosed);
        bool byBuyer = msg.sender == d.buyer;
        if (!(byBuyer || msg.sender == d.seller)) _f(E.OnlyParties);
        uint256 limit = MAX_EVIDENCE_PER_SIDE + (d.reopened ? EVIDENCE_REOPEN_BONUS : 0) + (d.challenged ? EVIDENCE_REOPEN_BONUS : 0);
        if (!((byBuyer ? d.evBuyer : d.evSeller) < limit)) _f(E.EvidenceLimit);
        if (!(_len(text, 5, 1500))) _f(E.TextLength);
        if (!(_validUrl(url))) _f(E.BadUrl);
        _addEvidence(d, byBuyer, text, url);
    }

    function resolveDispute(
        uint256 id,
        Verdict verdict,
        bytes32 reasonCode,
        string calldata reason,
        bool paymentEvidenceReviewed
    ) external {
        Deal storage d = _deal(id);
        if (!(msg.sender == arbiter)) _f(E.OnlyArbiter);
        if (!(_inDispute(d))) _f(E.NotInDispute);
        if (!(block.timestamp > d.evidenceDeadline)) _f(E.EvidenceWindowOpen);
        if (!(verdict != Verdict.NONE)) _f(E.VerdictRequired);
        if (!(bytes(reason).length <= 300)) _f(E.ReasonTooLong);
        bool silent = d.boundBy != 1;
        if (silent && (verdict == Verdict.BUYER_WINS || verdict == Verdict.SPLIT) && !paymentEvidenceReviewed) {
            verdict = Verdict.INSUFFICIENT_EVIDENCE;
            reasonCode = bytes32("NO_SUBSTANTIVE_EVIDENCE");
        }
        if (verdict == Verdict.INSUFFICIENT_EVIDENCE && !d.reopened && d.status != Status.CHALLENGED) {
            d.reopened = true;
            d.status = Status.REOPENED;
            d.evidenceDeadline = uint64(block.timestamp + reopenWindow);
            d.verdict = verdict;
            d.reasonCode = reasonCode;
            d.reason = reason;
            d.paymentEvidenceReviewed = paymentEvidenceReviewed;
            emit Reopened(id, d.evidenceDeadline);
            emit DealStatus(id, d.status);
            return;
        }
        if (silent && d.status != Status.CHALLENGED && (verdict == Verdict.BUYER_WINS || verdict == Verdict.SPLIT)) {
            uint256 pending = _compFor(d, verdict, paymentEvidenceReviewed);
            d.status = Status.PAYOUT_PENDING;
            d.verdict = verdict;
            d.reasonCode = reasonCode;
            d.reason = reason;
            d.paymentEvidenceReviewed = paymentEvidenceReviewed;
            d.pendingComp = pending;
            d.unlockAt = uint64(block.timestamp + payoutDelay);
            emit PayoutPending(id, pending, d.unlockAt);
            emit DealStatus(id, d.status);
            return;
        }
        _settle(d, verdict, reasonCode, reason, paymentEvidenceReviewed);
    }

    function challengePayout(uint256 id, string calldata text, string calldata url) external {
        Deal storage d = _deal(id);
        if (!(msg.sender == d.seller)) _f(E.OnlyVendor);
        if (!(d.status == Status.PAYOUT_PENDING)) _f(E.NoPendingPayout);
        if (!(block.timestamp < d.unlockAt)) _f(E.ChallengeWindowClosed);
        if (!(_len(text, 5, 1500))) _f(E.TextLength);
        if (!(_validUrl(url))) _f(E.BadUrl);
        d.reopened = true;
        _addEvidence(d, false, text, url);
        d.challenged = true;
        d.status = Status.CHALLENGED;
        d.pendingComp = 0;
        d.evidenceDeadline = uint64(block.timestamp + reopenWindow);
        emit PayoutChallenged(id);
        emit DealStatus(id, d.status);
    }

    function finalizePayout(uint256 id) external {
        Deal storage d = _deal(id);
        if (!(d.status == Status.PAYOUT_PENDING)) _f(E.NoPendingPayout);
        if (!(block.timestamp >= d.unlockAt)) _f(E.PayoutIsStillLocked);
        _settle(d, d.verdict, d.reasonCode, d.reason, d.paymentEvidenceReviewed);
    }

    function closeStalledDispute(uint256 id) external {
        Deal storage d = _deal(id);
        if (!(_inDispute(d))) _f(E.NotInDispute);
        if (!(block.timestamp > uint256(d.evidenceDeadline) + arbiterTimeout)) _f(E.ArbiterStillHasTime);
        _settle(d, Verdict.INSUFFICIENT_EVIDENCE, bytes32("ARBITER_TIMEOUT"), "Arbiter did not rule in time", false);
    }

    function _compFor(Deal storage d, Verdict verdict, bool reviewed) internal view returns (uint256 comp) {
        if (verdict == Verdict.BUYER_WINS) comp = d.protect;
        else if (verdict == Verdict.SPLIT) comp = d.protect / 2;
        if (comp > 0 && d.boundBy != 1) {
            if (!(reviewed)) _f(E.PaymentEvidenceNotReviewed);
            comp = _min(comp, (d.protect * TIMEOUT_CAP_BPS) / 10000);
        }
    }

    function _settle(Deal storage d, Verdict verdict, bytes32 code, string memory reason, bool reviewed) internal {
        Vendor storage v = vendors[d.seller];
        Group storage g = groups[d.groupKey];
        uint256 comp = _compFor(d, verdict, reviewed);
        uint256 fee = (comp * FEE_BPS) / 10000;
        uint256 total = comp + fee;
        uint256 vpay = _min(total, d.vendorLock);
        uint256 gpay = total - vpay;
        if (!(gpay <= d.groupLock)) _f(E.PayoutExceedsLocks);
        v.bond -= vpay;
        g.pool -= gpay;
        _release(d, v, g);
        treasury += fee;
        if (comp > 0) {
            _credit(d.buyer, comp);
            v.compensated += vpay;
            g.compensated += gpay;
        }
        uint256 dep = d.deposit;
        depositsHeld -= dep;
        _returnClaimDeposit(d, verdict == Verdict.SELLER_WINS);
        d.pendingComp = 0;
        if (verdict == Verdict.SELLER_WINS) {
            _credit(d.seller, dep);
            v.disputesWon += 1;
            g.disputesWon += 1;
        } else {
            _credit(d.buyer, dep);
            if (verdict == Verdict.BUYER_WINS) {
                v.disputesLost += 1;
                g.disputesLost += 1;
                if (v.status == VendorStatus.APPROVED) {
                    v.status = VendorStatus.SUSPENDED;
                    g.vendorsApproved -= 1;
                    emit VendorStatusChanged(d.seller, v.status);
                }
            } else if (verdict == Verdict.SPLIT) {
                v.disputesSplit += 1;
                g.disputesSplit += 1;
            } else {
                v.inconclusive += 1;
                g.inconclusive += 1;
            }
        }
        d.verdict = verdict;
        d.reasonCode = code;
        d.reason = reason;
        d.paymentEvidenceReviewed = reviewed;
        d.compensation = comp;
        d.fee = fee;
        d.paidVendor = vpay;
        d.paidGroup = gpay;
        d.resolvedAt = uint64(block.timestamp);
        d.status = Status.RESOLVED;
        emit Resolved(d.id, verdict, code, comp, reviewed);
        emit DealStatus(d.id, d.status);
    }

    function claim() external nonReentrant {
        uint256 amt = claimable[msg.sender];
        if (!(amt > 0)) _f(E.NothingToClaim);
        claimable[msg.sender] = 0;
        totalClaimable -= amt;
        (bool ok, ) = msg.sender.call{value: amt}("");
        if (!(ok)) _f(E.TransferFailed);
        emit Claimed(msg.sender, amt);
    }

    function collectFees() external onlyOwner {
        uint256 amt = treasury;
        if (!(amt > 0)) _f(E.NoFees);
        treasury = 0;
        _credit(owner, amt);
    }

    function getDeal(uint256 id) external view returns (Deal memory) {
        return _deal(id);
    }

    function getEvidence(uint256 id) external view returns (Evidence[] memory) {
        return evidences[id];
    }

    function groupKeyOf(string calldata slug) external pure returns (bytes32) {
        return keccak256(bytes(slug));
    }

    function groupInfo(string calldata slug) external view returns (GroupInfo memory) {
        return _groupInfo(keccak256(bytes(slug)));
    }

    function _groupInfo(bytes32 key) internal view returns (GroupInfo memory i) {
        Group storage g = groups[key];
        if (!(g.exists)) _f(E.UnknownGroup);
        i.slug = g.slug;
        i.admin = g.admin;
        i.name = g.name;
        i.platform = g.platform;
        i.inviteUrl = g.inviteUrl;
        i.pool = g.pool;
        i.locked = g.locked;
        i.compensated = g.compensated;
        i.createdAt = g.createdAt;
        i.vendorsTotal = g.vendorsTotal;
        i.vendorsApproved = g.vendorsApproved;
        i.dealsBound = g.dealsBound;
        i.completed = g.completed;
        i.disputesLost = g.disputesLost;
        i.disputesWon = g.disputesWon;
        i.disputesSplit = g.disputesSplit;
        i.inconclusive = g.inconclusive;
        i.activeDeals = g.activeDeals;
    }

    function groupCount() external view returns (uint256) {
        return groupList.length;
    }

    function groupAt(uint256 idx) external view returns (GroupInfo memory) {
        return _groupInfo(groupList[idx]);
    }

    function groupOf(address admin) external view returns (string memory) {
        bytes32 key = groupOfAdmin[admin];
        if (key == bytes32(0)) return "";
        return groups[key].slug;
    }

    function vendorInfo(address who) public view returns (VendorInfo memory i) {
        Vendor storage v = _vendor(who);
        Group storage g = groups[v.groupKey];
        i.owner = who;
        i.groupSlug = g.slug;
        i.handle = v.handle;
        i.status = v.status;
        i.bond = v.bond;
        i.locked = v.locked;
        i.available = v.status == VendorStatus.APPROVED ? _available(v, g) : 0;
        i.createdAt = v.createdAt;
        i.compensated = v.compensated;
        i.dealsBound = v.dealsBound;
        i.completedVerified = v.completedVerified;
        i.completedAuto = v.completedAuto;
        i.disputesLost = v.disputesLost;
        i.disputesSplit = v.disputesSplit;
        i.disputesWon = v.disputesWon;
        i.inconclusive = v.inconclusive;
        i.rejectedClaims = v.rejectedClaims;
        i.lapsed = v.lapsed;
        i.activeDeals = v.activeDeals;
        i.uniqueBuyers = v.uniqueBuyers;
    }

    function isVendor(address who) external view returns (bool) {
        return vendors[who].exists;
    }

    function vendorByHandle(string calldata handle) external view returns (address) {
        return handleOwners[keccak256(bytes(handle))];
    }

    function vendorCount() external view returns (uint256) {
        return vendorList.length;
    }

    function vendorAt(uint256 idx) external view returns (address) {
        return vendorList[idx];
    }

    function getProtection(address who) external view returns (uint256) {
        Vendor storage v = vendors[who];
        if (!v.exists || v.status != VendorStatus.APPROVED) return 0;
        return _available(v, groups[v.groupKey]);
    }

    function isProtected(address who, uint256 amount) external view returns (bool) {
        Vendor storage v = vendors[who];
        if (!v.exists || v.status != VendorStatus.APPROVED) return false;
        return amount <= _available(v, groups[v.groupKey]);
    }

    function totalBonds() public view returns (uint256 t) {
        for (uint256 i = 0; i < vendorList.length; i++) {
            t += vendors[vendorList[i]].bond;
        }
    }

    function totalPools() public view returns (uint256 t) {
        for (uint256 i = 0; i < groupList.length; i++) {
            t += groups[groupList[i]].pool;
        }
    }
}
