// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface IERC20 {
    function decimals() external view returns (uint8);
    function transfer(address recipient, uint256 amount) external;
    function transferFrom(address sender, address recipient, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract Asset is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    IERC20 public usdt;
    address public whiteListAddr; // white address
    address public withdrawAddr; // Application for withdrawal

    mapping(address => uint256) public balance; // user asset
    mapping(address => uint256) public lossBalance; // user loss asset
    mapping(address => uint256[]) internal depositRecords;
    mapping(address => bool) public canWithdraw; // Whether the user can withdraw cash
    uint256 public constant MAX_SIZE = 1000;

    event Deposit(address indexed user, uint256 amount);
    event CanWithdraw(address indexed user);
    event Withdraw(address indexed user, uint256 amount);
    event WithdrawQuantificationAmount(uint256 amount);
    event SetWithdrawAddr(address indexed user);
    event SetWhiteListAddr(address indexed user);

    modifier onlyWithdrawAddr() {
        require(msg.sender == withdrawAddr, "no withdraw addr");
        _;
    }

    function initialize(
        address _usdt,
        address _whiteListAddr,
        address _withdrawAddr
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        usdt = IERC20(_usdt);
        whiteListAddr = _whiteListAddr;
        withdrawAddr = _withdrawAddr;
    }

    function getDepositRecordsLength(address addr)
    external
    view
    returns (uint256)
    {
        return depositRecords[addr].length;
    }

    function getDepositRecords(
        address addr,
        uint256 cursor,
        uint256 size
    ) external view returns (uint256[] memory m, uint256) {
        require(size <= MAX_SIZE, "Exceed Size Limit");
        uint256 length = size;
        if (length > depositRecords[addr].length - cursor) {
            length = depositRecords[addr].length - cursor;
        }

        m = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            m[i] = depositRecords[addr][cursor + i];
        }
        return (m, cursor + length);
    }

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "deposit amount err");

        uint256 beforeTransferBalance = usdt.balanceOf(address(this));
        usdt.transferFrom(msg.sender, address(this), amount);
        uint256 afterTransferBalance = usdt.balanceOf(address(this));

        uint256 actualAmount = afterTransferBalance - beforeTransferBalance;

        balance[msg.sender] = balance[msg.sender] + actualAmount;
        depositRecords[msg.sender].push(actualAmount);

        emit Deposit(msg.sender, actualAmount);
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

    function permitWithdraw(address addr, uint256 amount, uint lossAmount) external onlyWithdrawAddr {
        require(amount > 0 && balance[addr] >= amount, "err amount");
        require(canWithdraw[addr], "The user did not apply for withdrawal");

        balance[addr] = balance[addr] - amount;
        canWithdraw[addr] = false;
        usdt.transfer(addr, amount);
        lossBalance[addr] = lossAmount;

        emit Withdraw(addr, amount);
    }

    function batchPermitWithdraw(address[] memory addrs, uint256[] memory amounts, uint256[] memory lossAmounts) external onlyWithdrawAddr {
        require(addrs.length == amounts.length && addrs.length == lossAmounts.length, "Array length mismatch");

        for (uint256 i = 0; i < addrs.length; i++) {
            address addr = addrs[i];
            uint256 amount = amounts[i];
            uint256 lossAmount = lossAmounts[i];

            require(amount > 0 && balance[addr] >= amount, "err amount");
            require(canWithdraw[addr], "The user did not apply for withdrawal");

            balance[addr] = balance[addr] - amount;
            canWithdraw[addr] = false;
            usdt.transfer(addr, amount);
            lossBalance[addr] = lossAmount;

            emit Withdraw(addr, amount);
        }
    }

    function withdrawQuantificationAmount(uint256 amount) external onlyWithdrawAddr {
        require(amount > 0, "err amount");

        usdt.transfer(whiteListAddr, amount);
        emit WithdrawQuantificationAmount(amount);
    }

    function withdrawFee() external onlyWithdrawAddr{
        payable(withdrawAddr).transfer(address(this).balance);
    }

    function setWithdrawAddr(address _withdrawAddr) public onlyOwner {
        withdrawAddr = _withdrawAddr;
        emit SetWithdrawAddr(withdrawAddr);
    }

    function setWhiteListAddr(address _whiteListAddr) public onlyOwner {
        whiteListAddr = _whiteListAddr;
        emit SetWhiteListAddr(whiteListAddr);
    }
}
