// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Registrasi Hak Cipta Karya Multimedia
/// @notice Mengelola pencatatan hak cipta digital berbasis IPFS dengan kontrol akses
contract MediaCopyrightRegistry {
    
    // Custom Error untuk efisiensi Gas
    error UnauthorizedAccess(address caller);
    error MediaAlreadyExists(bytes32 mediaId);
    error MediaNotFound(bytes32 mediaId);

    enum MediaType { Image, Audio, Video, Model3D }

    // Struct metadata karya multimedia yang sudah di-update
    struct MediaWork {
        bytes32 mediaId;
        string title;
        string ipfsHash;
        MediaType mediaType;
        address creator;
        uint256 timestamp;
        bool isVerified;
        address[] ownershipHistory; // Update 1: Array untuk menyimpan histori kepemilikan
    }

    address public admin;

    // Storage mappings
    mapping(bytes32 => MediaWork) private registry;
    mapping(address => bytes32[]) private creatorPortfolio;

    // Events
    event MediaRegistered(bytes32 indexed mediaId, address indexed creator, string ipfsHash);
    event MediaVerified(bytes32 indexed mediaId, address indexed verifier);
    event CopyrightTransferred(bytes32 indexed mediaId, address indexed oldOwner, address indexed newOwner);

    modifier onlyAdmin() {
        if (msg.sender != admin) revert UnauthorizedAccess(msg.sender);
        _;
    }

    // Update 2: Modifier untuk memastikan hanya pemilik saat ini yang bisa akses
    modifier onlyCreator(bytes32 _mediaId) {
        if (registry[_mediaId].creator != msg.sender) revert UnauthorizedAccess(msg.sender);
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    /// @dev Mendaftarkan hak cipta media baru
    function registerMedia(
        string calldata _title,
        string calldata _ipfsHash,
        MediaType _mediaType
    ) external returns (bytes32) {
        require(bytes(_title).length > 0, "Judul tidak boleh kosong");
        require(bytes(_ipfsHash).length > 0, "IPFS Hash wajib diisi");

        bytes32 mediaId = keccak256(abi.encodePacked(msg.sender, _ipfsHash, block.timestamp));
        if (registry[mediaId].timestamp != 0) revert MediaAlreadyExists(mediaId);

        // Menggunakan reference storage karena struct sekarang punya dynamic array
        MediaWork storage newWork = registry[mediaId];
        newWork.mediaId = mediaId;
        newWork.title = _title;
        newWork.ipfsHash = _ipfsHash;
        newWork.mediaType = _mediaType;
        newWork.creator = msg.sender;
        newWork.timestamp = block.timestamp;
        newWork.isVerified = false;
        newWork.ownershipHistory.push(msg.sender); // Menyimpan pemilik pertama ke histori

        creatorPortfolio[msg.sender].push(mediaId);

        emit MediaRegistered(mediaId, msg.sender, _ipfsHash);
        return mediaId;
    }

    /// @dev Verifikasi karya oleh Admin
    function verifyMedia(bytes32 _mediaId) external onlyAdmin {
        if (registry[_mediaId].timestamp == 0) revert MediaNotFound(_mediaId);
        registry[_mediaId].isVerified = true;
        emit MediaVerified(_mediaId, msg.sender);
    }

    /// @dev Memindahkan hak kepemilikan karya (Tugas Mandiri)
    function transferCopyright(bytes32 _mediaId, address _newOwner) external onlyCreator(_mediaId) {
        require(_newOwner != address(0), "Alamat pemilik baru tidak valid");
        require(registry[_mediaId].timestamp != 0, "Media tidak ditemukan");

        address oldOwner = registry[_mediaId].creator;

        // Memindahkan hak milik ke owner baru
        registry[_mediaId].creator = _newOwner;
        
        // Menambahkan owner baru ke dalam array histori
        registry[_mediaId].ownershipHistory.push(_newOwner);
        
        // Menambahkan karya ke portofolio owner baru
        creatorPortfolio[_newOwner].push(_mediaId);

        emit CopyrightTransferred(_mediaId, oldOwner, _newOwner);
    }

    /// @dev Membaca metadata media (Read-Only / Gasless)
    function getMedia(bytes32 _mediaId) external view returns (MediaWork memory) {
        if (registry[_mediaId].timestamp == 0) revert MediaNotFound(_mediaId);
        return registry[_mediaId];
    }

    /// @dev Mengambil daftar ID karya milik pencipta
    function getCreatorPortfolio(address _creator) external view returns (bytes32[] memory) {
        return creatorPortfolio[_creator];
    }

    /// @dev (Fungsi Helper) Melihat histori kepemilikan sebuah karya
    function getOwnershipHistory(bytes32 _mediaId) external view returns (address[] memory) {
        if (registry[_mediaId].timestamp == 0) revert MediaNotFound(_mediaId);
        return registry[_mediaId].ownershipHistory;
    }
}
