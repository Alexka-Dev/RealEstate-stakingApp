// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract RealEstateToken is ERC20, Ownable {
    constructor(
        string memory name_,
        string memory symbol_,
        address owner_
    ) ERC20(name_, symbol_) Ownable(owner_) {}

    function mint(uint256 amount_) external onlyOwner {
        _mint(msg.sender, amount_);
    }
}
