// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

enum FileStorageMode {
    SSTORE2, // Store on the ethereum network itself using SSTORE2
    EthStorage // Store with the EthStorage project
}

struct FileInfos {
    // The path of the file, without root slash. E.g. "images/logo.png"
    string filePath;
    // The content type of the file, e.g. "image/png"
    string contentType;

    // Pointers to the file contents
    // If storage mode is SSTORE2, then there will only be one address pointer to the SSTORE2 file
    // If storage mode is EthStorage, then these are the keys to the EthStorage file parts
    // Note: These files are expected to be compressed with gzip
    bytes32[] contentKeys;
}

// A version of a frontend, containing some static files
struct FrontendFilesSet {
    // Storage mode for the frontend files
    FileStorageMode storageMode;

    // The files of the frontend
    FileInfos[] files;

    // Infos about this frontend version
    string infos;

    // When locked, the frontend version cannot be modified any longer
    bool locked;
}

// When we want to store the storage mode of individual files
struct FileInfosWithStorageMode {
    // Storage mode of the file
    FileStorageMode storageMode;

    FileInfos fileInfos;
}


// Temporary name, to be renamed to FileInfos once legacy FileInfos is removed
struct FileInfos2 {
    // The path of the file, without root slash. E.g. "images/logo.png"
    string filePath;
    // The content type of the file, e.g. "image/png"
    string contentType;

    // Pointers to the file contents on a storage backend
    uint contentKey;
}

// A version of a frontend, containing some static files
// Temporary name, to be renamed to FileInfos once legacy FileInfos is removed
struct FrontendFilesSet2 {
    // Storage backend for the frontend files
    uint16 storageBackendIndex;

    // The files of the frontend
    FileInfos2[] files;

    // Infos about this frontend version
    string infos;

    // When locked, the frontend version cannot be modified any longer
    bool locked;
}

// When we want to store the storage backend of individual files
struct FileInfosWithStorageBackend {
    // Storage backend of the file
    uint16 storageBackendIndex;

    FileInfos2 fileInfos;
}