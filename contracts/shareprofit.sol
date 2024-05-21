//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ShareProfit is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable withdrawAddr; // Application for withdrawal
    mapping(address => bool) public canWithdraw; // Whether the user can withdraw cash

    event CanWithdraw(address indexed user);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event WithdrawQuantificationAmount(address indexed token, uint256 amount);


    modifier onlyWithdrawAddr() {
        require(msg.sender == withdrawAddr, "no withdraw addr");
        _;
    }

    constructor(address _withdrawAddr) {
        withdrawAddr = _withdrawAddr;
    }

    function applyForWithdraw() external payable {
        require(msg.value >= 300000000000000, "Insufficient balance sent"); // bsc Minimum handling fee

        if (msg.value > 300000000000000) {
            uint256 excessAmount = msg.value - 300000000000000;
            payable(msg.sender).transfer(excessAmount);
        }

        canWithdraw[msg.sender] = true;

        emit CanWithdraw(msg.sender);
    }

    function permitWithdraw(address addr, address token, uint256 amount) external onlyWithdrawAddr {
        require(amount > 0, "err amount");
        require(canWithdraw[addr], "The user did not apply for withdrawal");
        IERC20(token).safeTransfer(addr, amount);

        emit Withdraw(addr, token, amount);
    }

    function batchPermitWithdraw(address[] memory addrs, address token, uint256[] memory amounts) external onlyWithdrawAddr {
        require(addrs.length == amounts.length, "Array length mismatch");

        for (uint256 i = 0; i < addrs.length; i++) {
            address addr = addrs[i];
            uint256 amount = amounts[i];

            require(amount > 0, "err amount");
            require(canWithdraw[addr], "The user did not apply for withdrawal");
            IERC20(token).safeTransfer(addr, amount);

            emit Withdraw(addr, token, amount);
        }
    }

    function withdrawQuantificationAmount(address token, uint256 amount) external onlyWithdrawAddr {
        IERC20(token).safeTransfer(owner(), amount);
        emit WithdrawQuantificationAmount(token, amount);
    }

    function withdrawFee() external onlyWithdrawAddr{
        payable(withdrawAddr).transfer(address(this).balance);
    }
}