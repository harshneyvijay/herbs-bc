// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AyurvedicHerbProvenance {

    /* ============================================================
                            ROLE SYSTEM
    ============================================================ */

    mapping(address => mapping(uint256 => bool)) public roles;
    mapping(uint256 => string) public roleNames;
    mapping(uint256 => bool) public roleExists;

    uint256 public constant ADMIN_ROLE = 1;
    uint256 public constant FARMER_ROLE = 2;
    uint256 public constant GPS_VERIFIER_ROLE = 3;
    uint256 public constant SUPPLIER_ROLE = 4;
    uint256 public constant PROCESSOR_ROLE = 5;
    uint256 public constant LAB_TESTER_ROLE = 6;
    uint256 public constant TRANSPORTER_ROLE = 7;
    uint256 public constant EXPORTER_ROLE = 8;
    uint256 public constant RETAILER_ROLE = 9;
    uint256 public constant REGULATOR_ROLE = 10;
    uint256 public constant CONSUMER_ROLE = 11;
    uint256 public constant QUALITY_AUDITOR_ROLE = 12;

    modifier onlyRole(uint256 roleId) {
        require(roles[msg.sender][roleId], "Not authorized");
        _;
    }

    modifier onlyAdmin() {
        require(roles[msg.sender][ADMIN_ROLE], "Admin only");
        _;
    }

    constructor() {
        roleNames[ADMIN_ROLE] = "ADMIN";
        roleExists[ADMIN_ROLE] = true;
        roles[msg.sender][ADMIN_ROLE] = true;

        roleNames[FARMER_ROLE] = "FARMER";
        roleNames[GPS_VERIFIER_ROLE] = "GPS_VERIFIER";
        roleNames[SUPPLIER_ROLE] = "SUPPLIER";
        roleNames[PROCESSOR_ROLE] = "PROCESSOR";
        roleNames[LAB_TESTER_ROLE] = "LAB_TESTER";
        roleNames[TRANSPORTER_ROLE] = "TRANSPORTER";
        roleNames[EXPORTER_ROLE] = "EXPORTER";
        roleNames[RETAILER_ROLE] = "RETAILER";
        roleNames[REGULATOR_ROLE] = "REGULATOR";
        roleNames[CONSUMER_ROLE] = "CONSUMER";
        roleNames[QUALITY_AUDITOR_ROLE] = "QUALITY_AUDITOR";

        for (uint256 i = 2; i <= 12; i++) {
            roleExists[i] = true;
        }
    }

    function registerUser(address user, uint256 roleId)
        external
        onlyAdmin
    {
        require(roleExists[roleId], "Role does not exist");
        roles[user][roleId] = true;
    }

    function revokeUserRole(address user, uint256 roleId)
        external
        onlyAdmin
    {
        roles[user][roleId] = false;
    }

    function createRole(uint256 roleId, string calldata name)
        external
        onlyAdmin
    {
        require(!roleExists[roleId], "Role already exists");
        require(roleId != 0, "Invalid role");

        roleNames[roleId] = name;
        roleExists[roleId] = true;
    }

    /* ============================================================
                            HERB STRUCT
    ============================================================ */

    struct Herb {
        bytes32 name;
        bytes32 gpsLocation;

        address collector;
        address verifier;

        bool verified;
        bool labApproved;
        bool exportApproved;
        bool frozen;
        bool locked;

        bytes32 labReportHash;

        address labTester;
        address exporter;
        address frozenBy;
    }

    mapping(bytes32 => Herb) private herbs;

    /* ============================================================
                            EVENTS
    ============================================================ */

    event HerbRecorded(bytes32 batchId, address indexed collector);
    event HerbVerified(bytes32 batchId, address indexed verifier);
    event StageUpdated(bytes32 batchId, Stage stage, address indexed actor);
    event ProofAnchored(
        bytes32 indexed collectionId,
        bytes32 hash,
        address indexed actor,
        uint256 timestamp
    );

    /* ============================================================
                            CORE FUNCTIONS
    ============================================================ */

    function recordHerb(
        bytes32 name,
        bytes32 batchId,
        bytes32 gpsLocation
    )
        external
        onlyRole(FARMER_ROLE)
    {
        require(herbs[batchId].collector == address(0), "Batch exists");

        herbs[batchId] = Herb({
            name: name,
            gpsLocation: gpsLocation,
            collector: msg.sender,
            verifier: address(0),
            verified: false,
            labApproved: false,
            exportApproved: false,
            frozen: false,
            locked: false,
            labReportHash: 0,
            labTester: address(0),
            exporter: address(0),
            frozenBy: address(0)
        });

        emit HerbRecorded(batchId, msg.sender);
    }

    function verifyHerb(bytes32 batchId)
        external
        onlyRole(GPS_VERIFIER_ROLE)
    {
        Herb storage h = herbs[batchId];

        require(h.collector != address(0), "Invalid batch");
        require(!h.verified, "Already verified");
        require(!h.frozen, "Batch frozen");

        h.verified = true;
        h.verifier = msg.sender;

        emit HerbVerified(batchId, msg.sender);
    }

    function certifyLab(bytes32 batchId, bytes32 reportHash)
        external
        onlyRole(LAB_TESTER_ROLE)
    {
        Herb storage h = herbs[batchId];

        require(h.collector != address(0), "Invalid batch");
        require(h.verified, "GPS not verified");
        require(!h.labApproved, "Already lab approved");
        require(!h.frozen && !h.locked, "Batch restricted");

        h.labApproved = true;
        h.labReportHash = reportHash;
        h.labTester = msg.sender;
    }

    function approveExport(bytes32 batchId)
        external
        onlyRole(EXPORTER_ROLE)
    {
        Herb storage h = herbs[batchId];

        require(h.collector != address(0), "Invalid batch");
        require(h.labApproved, "Lab approval required");
        require(!h.exportApproved, "Already exported");
        require(!h.frozen && !h.locked, "Batch restricted");

        h.exportApproved = true;
        h.exporter = msg.sender;
    }

    function freezeBatch(bytes32 batchId)
        external
        onlyRole(REGULATOR_ROLE)
    {
        Herb storage h = herbs[batchId];

        require(h.collector != address(0), "Invalid batch");
        require(!h.frozen, "Already frozen");

        h.frozen = true;
        h.frozenBy = msg.sender;
    }

    function unfreezeBatch(bytes32 batchId)
        external
        onlyRole(REGULATOR_ROLE)
    {
        Herb storage h = herbs[batchId];

        require(h.collector != address(0), "Invalid batch");
        require(h.frozen, "Not frozen");

        h.frozen = false;
    }

    function lockBatch(bytes32 batchId)
        external
        onlyRole(RETAILER_ROLE)
    {
        Herb storage h = herbs[batchId];

        require(h.collector != address(0), "Invalid batch");
        require(!h.locked, "Already locked");
        require(h.exportApproved, "Not exported");

        h.locked = true;
    }

    function getHerb(bytes32 batchId)
        external
        view
        returns (Herb memory)
    {
        return herbs[batchId];
    }

    /* ============================================================
                        SUPPLY CHAIN STAGES
    ============================================================ */

    enum Stage {
        COLLECTED,
        PROCESSED,
        PACKAGED,
        TRANSPORTED,
        SOLD
    }

    struct StageUpdate {
        Stage stage;
        bytes32 details;
        uint256 timestamp;
        address actor;
    }

    mapping(bytes32 => StageUpdate[]) private batchHistory;

    function updateStage(
        bytes32 batchId,
        Stage stage,
        bytes32 details
    )
        external
    {
        require(
            roles[msg.sender][PROCESSOR_ROLE] ||
            roles[msg.sender][SUPPLIER_ROLE] ||
            roles[msg.sender][TRANSPORTER_ROLE] ||
            roles[msg.sender][RETAILER_ROLE],
            "Not authorized"
        );

        require(herbs[batchId].collector != address(0), "Invalid batch");
        require(!herbs[batchId].locked && !herbs[batchId].frozen, "Restricted");

        batchHistory[batchId].push(
            StageUpdate({
                stage: stage,
                details: details,
                timestamp: block.timestamp,
                actor: msg.sender
            })
        );

        emit StageUpdated(batchId, stage, msg.sender);
    }

    function getBatchHistory(bytes32 batchId)
        external
        view
        returns (StageUpdate[] memory)
    {
        return batchHistory[batchId];
    }

    /* ============================================================
                        HASH ANCHORING
    ============================================================ */

    mapping(bytes32 => bytes32[]) private anchoredHashes;
    mapping(bytes32 => mapping(bytes32 => bool)) private hashExists;
    mapping(address => bool) public authorizedAnchors;

    function setAnchorAuthorization(address actor, bool allowed)
        external
        onlyRole(ADMIN_ROLE)
    {
        authorizedAnchors[actor] = allowed;
    }

    function anchorHash(bytes32 collectionId, bytes32 hash)
        external
    {
        require(authorizedAnchors[msg.sender], "Not authorized");
        require(!hashExists[collectionId][hash], "Already anchored");

        anchoredHashes[collectionId].push(hash);
        hashExists[collectionId][hash] = true;

        emit ProofAnchored(
            collectionId,
            hash,
            msg.sender,
            block.timestamp
        );
    }

    function verifyHash(bytes32 collectionId, bytes32 hash)
        external
        view
        returns (bool)
    {
        return hashExists[collectionId][hash];
    }

    function getAnchoredHashCount(bytes32 collectionId)
        external
        view
        returns (uint256)
    {
        return anchoredHashes[collectionId].length;
    }
}
