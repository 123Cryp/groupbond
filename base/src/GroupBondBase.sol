// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract GroupBondBase {
    enum Status { OPEN, PAYMENT_CLAIMED, ACTIVE, DELIVERED, COMPLETED, DISPUTED, REOPENED, RESOLVED, CANCELLED, EXPIRED, PAYOUT_PENDING, CHALLENGED }
    enum Verdict { NONE, BUYER_WINS, SELLER_WINS, SPLIT, INSUFFICIENT_EVIDENCE }
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
        uint256 free;
        uint8 level;
        uint256 score;
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
        uint256 maxProtect;
        uint256 score;
        uint8 level;
        bool trusted;
        uint256 compensated;
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
    uint256 public constant TRUSTED_MIN_COMPLETED = 5;
    uint256 public constant TRUSTED_MIN_VERIFIED = 3;
    uint256 public constant TRUSTED_MIN_UNIQUE = 5;
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
    uint256 public immutable arbiterChangeDelay;

    address public owner;
    address public arbiter;
    address public pendingArbiter;
    uint256 public arbiterChangeAt;
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
    mapping(uint256 => address) public disputeArbiter;

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
    event ArbiterChanged(address indexed arbiter);
    event ArbiterProposed(address indexed arbiter, uint256 effectiveAt);
    event ArbiterProposalCancelled(address indexed arbiter);

    modifier nonReentrant() {
        require(lockFlag == 1, "reentrancy");
        lockFlag = 2;
        _;
        lockFlag = 1;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    constructor(address arbiter_, uint256 unit_) {
        require(arbiter_ != address(0), "arbiter required");
        require(unit_ >= 1 && unit_ <= 86400, "bad unit");
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
        arbiterChangeDelay = 168 * unit_;
        emit ArbiterChanged(arbiter_);
    }

    function proposeArbiter(address a) external onlyOwner {
        require(a != address(0), "arbiter required");
        pendingArbiter = a;
        arbiterChangeAt = block.timestamp + arbiterChangeDelay;
        emit ArbiterProposed(a, arbiterChangeAt);
    }

    function cancelArbiterChange() external onlyOwner {
        require(pendingArbiter != address(0), "nothing proposed");
        emit ArbiterProposalCancelled(pendingArbiter);
        pendingArbiter = address(0);
        arbiterChangeAt = 0;
    }

    function applyArbiterChange() external {
        require(pendingArbiter != address(0), "nothing proposed");
        require(block.timestamp >= arbiterChangeAt, "change is still locked");
        arbiter = pendingArbiter;
        pendingArbiter = address(0);
        arbiterChangeAt = 0;
        emit ArbiterChanged(arbiter);
    }

    function transferOwnership(address a) external onlyOwner {
        require(a != address(0), "zero address");
        owner = a;
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

    function _groupLevel(uint256 pool) internal pure returns (uint8) {
        if (pool >= 0.05 ether) return 2;
        if (pool >= 0.02 ether) return 1;
        return 0;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _completed(Vendor storage v) internal view returns (uint256) {
        return uint256(v.completedVerified) + uint256(v.completedAuto);
    }

    function _trusted(Vendor storage v) internal view returns (bool) {
        return _completed(v) >= TRUSTED_MIN_COMPLETED && v.completedVerified >= TRUSTED_MIN_VERIFIED
            && v.uniqueBuyers >= TRUSTED_MIN_UNIQUE && block.timestamp >= uint256(v.createdAt) + trustedMinAge && v.disputesLost == 0;
    }

    function _vendorScore(Vendor storage v) internal view returns (uint256) {
        int256 x = 500;
        x += 12 * int256(_min(v.completedVerified, 40));
        x += 4 * int256(_min(v.completedAuto, 40));
        x += 15 * int256(_min(v.disputesWon, 20));
        x -= 90 * int256(uint256(v.disputesLost));
        x -= 40 * int256(uint256(v.disputesSplit));
        x -= 25 * int256(uint256(v.inconclusive));
        x -= 15 * int256(uint256(v.lapsed));
        if (x < 0) return 0;
        if (x > 1000) return 1000;
        return uint256(x);
    }

    function _groupScore(Group storage g) internal view returns (uint256) {
        int256 x = 500;
        x += 8 * int256(_min(g.completed, 60));
        x += 12 * int256(_min(g.disputesWon, 20));
        x -= 80 * int256(uint256(g.disputesLost));
        x -= 30 * int256(uint256(g.disputesSplit));
        x -= 20 * int256(uint256(g.inconclusive));
        if (x < 0) return 0;
        if (x > 1000) return 1000;
        return uint256(x);
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
        require(v.exists, "not a registered vendor");
    }

    function _adminGroup(address who) internal view returns (Group storage g, bytes32 key) {
        key = groupOfAdmin[who];
        require(key != bytes32(0), "not a group admin");
        g = groups[key];
    }

    function _deal(uint256 id) internal view returns (Deal storage d) {
        require(id < dealCount, "unknown deal");
        d = deals[id];
    }

    function _release(Deal storage d, Vendor storage v, Group storage g) internal {
        v.locked -= d.vendorLock;
        g.locked -= d.groupLock;
        v.activeDeals -= 1;
        g.activeDeals -= 1;
    }

    function createGroup(string calldata slug, string calldata name, uint8 platform, string calldata inviteUrl) external payable {
        require(_validKey(slug, 3, 30, false), "invalid slug");
        bytes32 key = keccak256(bytes(slug));
        require(!groups[key].exists, "slug taken");
        require(groupOfAdmin[msg.sender] == bytes32(0), "already admin");
        require(!vendors[msg.sender].exists, "already vendor");
        require(_len(name, 3, 60), "invalid name");
        require(platform <= 4, "invalid platform");
        require(_validUrl(inviteUrl), "bad url");
        require(msg.value >= MIN_POOL, "pool below minimum");
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
        require(msg.value > 0, "no value");
        g.pool += msg.value;
        emit PoolChanged(key, g.pool);
    }

    function withdrawPool(uint256 amount) external {
        (Group storage g, bytes32 key) = _adminGroup(msg.sender);
        require(amount > 0, "amount must be positive");
        require(amount <= g.pool - g.locked, "amount exceeds free pool");
        g.pool -= amount;
        _credit(msg.sender, amount);
        emit PoolChanged(key, g.pool);
    }

    function joinGroup(string calldata slug, string calldata handle) external payable {
        bytes32 key = keccak256(bytes(slug));
        Group storage g = groups[key];
        require(g.exists, "unknown group");
        require(_validKey(handle, 3, 30, true), "invalid handle");
        require(!vendors[msg.sender].exists, "already registered");
        require(groupOfAdmin[msg.sender] == bytes32(0), "admin cannot sell");
        bytes32 hk = keccak256(bytes(handle));
        require(handleOwners[hk] == address(0), "handle taken");
        require(msg.value >= MIN_BOND, "bond below minimum");
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
        require(msg.value > 0, "no value");
        v.bond += msg.value;
        emit BondChanged(msg.sender, v.bond);
    }

    function withdrawBond(uint256 amount) external {
        Vendor storage v = _vendor(msg.sender);
        require(amount > 0, "amount must be positive");
        require(amount <= v.bond - v.locked, "amount exceeds free bond");
        v.bond -= amount;
        _credit(msg.sender, amount);
        emit BondChanged(msg.sender, v.bond);
    }

    function approveVendor(address who) external {
        (Group storage g, bytes32 key) = _adminGroup(msg.sender);
        Vendor storage v = _vendor(who);
        require(v.groupKey == key, "vendor is not in your group");
        require(v.status == VendorStatus.PENDING || v.status == VendorStatus.SUSPENDED, "vendor cannot be approved now");
        v.status = VendorStatus.APPROVED;
        if (v.approvedAt == 0) v.approvedAt = uint64(block.timestamp);
        g.vendorsApproved += 1;
        emit VendorStatusChanged(who, v.status);
    }

    function suspendVendor(address who) external {
        (Group storage g, bytes32 key) = _adminGroup(msg.sender);
        Vendor storage v = _vendor(who);
        require(v.groupKey == key, "vendor is not in your group");
        require(v.status == VendorStatus.APPROVED, "vendor is not approved");
        v.status = VendorStatus.SUSPENDED;
        g.vendorsApproved -= 1;
        emit VendorStatusChanged(who, v.status);
    }

    function removeVendor(address who) external {
        (Group storage g, bytes32 key) = _adminGroup(msg.sender);
        Vendor storage v = _vendor(who);
        require(v.groupKey == key, "vendor is not in your group");
        _remove(v, g, who);
    }

    function leaveGroup() external {
        Vendor storage v = _vendor(msg.sender);
        _remove(v, groups[v.groupKey], msg.sender);
    }

    function _remove(Vendor storage v, Group storage g, address who) internal {
        require(v.status != VendorStatus.REMOVED, "already removed");
        require(v.activeDeals == 0, "vendor has active deals");
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
        require(v.status == VendorStatus.APPROVED, "vendor is not approved");
        Group storage g = groups[v.groupKey];
        require(_len(item, 3, 200), "item length");
        require(_len(priceText, 1, 80), "price length");
        require(_validUrl(listingUrl), "bad url");
        require(protect >= MIN_PROTECT, "protect below minimum");
        require(protect <= _maxProtect(_level(v.bond)), "protect above level cap");
        require(deliveryHours >= 1 && deliveryHours <= MAX_DELIVERY_HOURS, "delivery hours");
        uint256 vlock = (protect * VENDOR_BPS) / 10000;
        uint256 glock = (protect * GROUP_BPS) / 10000;
        require(vlock <= v.bond - v.locked, "not enough free vendor bond");
        require(glock <= g.pool - g.locked, "not enough free group pool");
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
        require(msg.sender == d.seller, "only vendor");
        require(d.status == Status.OPEN, "deal is not open");
        _release(d, vendors[d.seller], groups[d.groupKey]);
        d.status = Status.CANCELLED;
        d.resolvedAt = uint64(block.timestamp);
        emit DealStatus(id, d.status);
    }

    function expireOffer(uint256 id) external {
        Deal storage d = _deal(id);
        require(d.status == Status.OPEN, "deal is not open");
        require(block.timestamp > d.offerExpires, "offer has not expired");
        _release(d, vendors[d.seller], groups[d.groupKey]);
        d.status = Status.EXPIRED;
        d.resolvedAt = uint64(block.timestamp);
        emit DealStatus(id, d.status);
    }

    function claimPayment(uint256 id, string calldata paymentRef) external payable {
        Deal storage d = _deal(id);
        require(d.status == Status.OPEN, "deal not open");
        require(block.timestamp <= d.offerExpires, "offer expired");
        require(msg.sender != d.seller, "vendor cannot buy own deal");
        require(msg.sender != groups[d.groupKey].admin, "admin cannot buy in own group");
        require(msg.value == CLAIM_DEPOSIT, "wrong deposit");
        require(_len(paymentRef, 5, 300), "payment ref length");
        require(!rejectedClaim[keccak256(abi.encodePacked(id, msg.sender))], "claim was rejected");
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
        require(msg.sender == d.seller, "only vendor");
        require(d.status == Status.PAYMENT_CLAIMED, "no payment claim to answer");
        if (accept) {
            _bind(d, 1);
            return;
        }
        require(_len(reason, 5, 200), "reason length");
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
        require(d.status == Status.PAYMENT_CLAIMED, "no payment claim pending");
        require(block.timestamp >= uint256(d.claimedAt) + confirmWindow, "vendor still has time");
        _bind(d, 2);
    }

    function submitDelivery(uint256 id, string calldata text, string calldata url) external {
        Deal storage d = _deal(id);
        require(msg.sender == d.seller, "only vendor");
        require(d.status == Status.ACTIVE, "deal is not active");
        require(_len(text, 3, 1500), "delivery text length");
        require(_validUrl(url), "bad url");
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
        require(msg.sender == d.buyer, "only buyer");
        require(d.status == Status.DELIVERED, "delivery not claimed");
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
            require(block.timestamp > uint256(d.deliveredAt) + reviewWindow, "review window still open");
            _release(d, v, g);
            _creditCompletion(d, v, false);
            g.completed += 1;
            _returnClaimDeposit(d, false);
            d.status = Status.COMPLETED;
        } else if (d.status == Status.ACTIVE) {
            require(block.timestamp > uint256(d.deliveryDeadline) + reviewWindow, "dispute window still open");
            _release(d, v, g);
            v.lapsed += 1;
            _returnClaimDeposit(d, false);
            d.status = Status.EXPIRED;
        } else {
            revert("deal cannot be finalized");
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
        require(msg.sender == d.buyer, "only buyer");
        require(msg.value == DISPUTE_DEPOSIT, "wrong deposit");
        bool late = d.status == Status.ACTIVE && block.timestamp > d.deliveryDeadline
            && block.timestamp <= uint256(d.deliveryDeadline) + reviewWindow;
        bool mismatch = d.status == Status.DELIVERED && block.timestamp <= uint256(d.deliveredAt) + reviewWindow;
        require(late || mismatch, "not disputable now");
        require(_len(claimText, 10, 1500), "claim length");
        require(_validUrl(url), "bad url");
        d.deposit = msg.value;
        depositsHeld += msg.value;
        disputeArbiter[id] = arbiter;
        d.evidenceDeadline = uint64(block.timestamp + evidenceWindow);
        d.disputeOpenedAt = uint64(block.timestamp);
        d.status = Status.DISPUTED;
        _addEvidence(d, true, claimText, url);
        emit DealStatus(id, d.status);
    }

    function submitEvidence(uint256 id, string calldata text, string calldata url) external {
        Deal storage d = _deal(id);
        require(_inDispute(d), "not in dispute");
        require(block.timestamp <= d.evidenceDeadline, "window closed");
        bool byBuyer = msg.sender == d.buyer;
        require(byBuyer || msg.sender == d.seller, "only parties");
        uint256 limit = MAX_EVIDENCE_PER_SIDE + (d.reopened ? EVIDENCE_REOPEN_BONUS : 0) + (d.challenged ? EVIDENCE_REOPEN_BONUS : 0);
        require((byBuyer ? d.evBuyer : d.evSeller) < limit, "evidence limit");
        require(_len(text, 5, 1500), "text length");
        require(_validUrl(url), "bad url");
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
        require(msg.sender == disputeArbiter[id], "only arbiter");
        require(_inDispute(d), "not in dispute");
        require(block.timestamp > d.evidenceDeadline, "evidence window open");
        require(verdict != Verdict.NONE, "verdict required");
        require(bytes(reason).length <= 300, "reason too long");
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
        require(msg.sender == d.seller, "only vendor");
        require(d.status == Status.PAYOUT_PENDING, "no pending payout");
        require(block.timestamp < d.unlockAt, "challenge window closed");
        require(_len(text, 5, 1500), "text length");
        require(_validUrl(url), "bad url");
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
        require(d.status == Status.PAYOUT_PENDING, "no pending payout");
        require(block.timestamp >= d.unlockAt, "payout is still locked");
        _settle(d, d.verdict, d.reasonCode, d.reason, d.paymentEvidenceReviewed);
    }

    function closeStalledDispute(uint256 id) external {
        Deal storage d = _deal(id);
        require(_inDispute(d), "not in dispute");
        require(block.timestamp > uint256(d.evidenceDeadline) + arbiterTimeout, "arbiter still has time");
        _settle(d, Verdict.INSUFFICIENT_EVIDENCE, bytes32("ARBITER_TIMEOUT"), "Arbiter did not rule in time", false);
    }

    function _compFor(Deal storage d, Verdict verdict, bool reviewed) internal view returns (uint256 comp) {
        if (verdict == Verdict.BUYER_WINS) comp = d.protect;
        else if (verdict == Verdict.SPLIT) comp = d.protect / 2;
        if (comp > 0 && d.boundBy != 1) {
            require(reviewed, "payment evidence not reviewed");
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
        require(gpay <= d.groupLock, "payout exceeds locks");
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
        require(amt > 0, "nothing to claim");
        claimable[msg.sender] = 0;
        totalClaimable -= amt;
        (bool ok, ) = msg.sender.call{value: amt}("");
        require(ok, "transfer failed");
        emit Claimed(msg.sender, amt);
    }

    function collectFees() external onlyOwner {
        uint256 amt = treasury;
        require(amt > 0, "no fees");
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
        require(g.exists, "unknown group");
        i.slug = g.slug;
        i.admin = g.admin;
        i.name = g.name;
        i.platform = g.platform;
        i.inviteUrl = g.inviteUrl;
        i.pool = g.pool;
        i.locked = g.locked;
        i.free = g.pool - g.locked;
        i.level = _groupLevel(g.pool);
        i.score = _groupScore(g);
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
        i.maxProtect = _maxProtect(_level(v.bond));
        i.score = _vendorScore(v);
        i.level = _level(v.bond);
        i.trusted = _trusted(v);
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
