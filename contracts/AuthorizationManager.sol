// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract AuthorizationManager {
    // Address that is allowed to sign authorizations (off-chain signer)
    address public signer;

    // Tracks which authorization hashes have already been used (replay protection)
    mapping(bytes32 => bool) public usedAuthorizations;

    // Emitted whenever an authorization is successfully consumed
    event AuthorizationUsed(
        bytes32 indexed authHash,
        address indexed vault,
        address indexed recipient,
        uint256 amount,
        bytes32 authId
    );

    constructor(address _signer) {
        require(_signer != address(0), "invalid signer");
        signer = _signer;
    }

    // Builds a deterministic hash bound to:
    // - vault
    // - chainId
    // - recipient
    // - amount
    // - unique authorization id
    function _getAuthorizationHash(
        address vault,
        uint256 chainId,
        address recipient,
        uint256 amount,
        bytes32 authId
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(vault, chainId, recipient, amount, authId)
        );
    }

    // Called by the vault to verify a withdrawal authorization
    function verifyAuthorization(
        address vault,
        address recipient,
        uint256 amount,
        bytes32 authId,
        bytes calldata signature
    ) external returns (bool) {
        // 1) Build deterministic authorization hash
        bytes32 authHash = _getAuthorizationHash(
            vault,
            block.chainid,
            recipient,
            amount,
            authId
        );

        // 2) Ensure this authorization has not been used before
        require(!usedAuthorizations[authHash], "authorization already used");

        // 3) Recover signer from signature (Ethereum signed message)
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", authHash)
        );
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(signature);
        address recovered = ecrecover(ethSignedHash, v, r, s);
        require(recovered == signer, "invalid signer");

        // 4) Mark authorization as consumed
        usedAuthorizations[authHash] = true;

        // 5) Emit event for observability
        emit AuthorizationUsed(authHash, vault, recipient, amount, authId);

        return true;
    }

    // Helper to split a 65-byte signature into r, s, v
    function _splitSignature(bytes memory sig)
        internal
        pure
        returns (bytes32 r, bytes32 s, uint8 v)
    {
        require(sig.length == 65, "invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
