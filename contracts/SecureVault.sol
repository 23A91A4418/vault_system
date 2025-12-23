// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./AuthorizationManager.sol";

contract SecureVault {
    AuthorizationManager public authManager;

    // Internal accounting
    uint256 public totalDeposited;
    uint256 public totalWithdrawn;

    // Events
    event Deposit(address indexed sender, uint256 amount);
    event Withdrawal(address indexed recipient, uint256 amount, bytes32 authId);

    constructor(AuthorizationManager _authManager) {
        authManager = _authManager;
    }

    // Accept deposits of native currency
    receive() external payable {
        require(msg.value > 0, "no value");
        totalDeposited += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    // Withdrawal entrypoint, relies entirely on AuthorizationManager
    function withdraw(
        address payable recipient,
        uint256 amount,
        bytes32 authId,
        bytes calldata signature
    ) external {
        require(recipient != address(0), "invalid recipient");
        require(amount > 0, "amount must be > 0");

        // 1) Ask AuthorizationManager if this is allowed
        bool ok = authManager.verifyAuthorization(
            address(this),
            recipient,
            amount,
            authId,
            signature
        );
        require(ok, "not authorized");

        // 2) Check vault has enough balance
        require(address(this).balance >= amount, "insufficient vault balance");

        // 3) Update internal accounting BEFORE transfer
        totalWithdrawn += amount;

        // 4) Transfer funds
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "transfer failed");

        // 5) Emit event
        emit Withdrawal(recipient, amount, authId);
    }
}
