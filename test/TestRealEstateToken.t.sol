// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "../src/RealEstateToken.sol";

contract TestRealEstateToken is Test {
    RealEstateToken token;
    address owner = address(0xA11CE);

    function setUp() public {
        vm.prank(owner);
        token = new RealEstateToken("Real Estate Token", "RET", owner);
    }

    function testNonOwnerCannotMint(address randomUser, uint256 amount) public {
        vm.assume(randomUser != owner); // Evita colisiones
        vm.assume(randomUser != address(0)); // Evita address(0)
        vm.assume(amount > 0);

        vm.prank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                randomUser
            )
        );
        token.mint(amount);
    }

    function testOwnerCanMint(uint256 amount) public {
        vm.assume(amount > 0);

        vm.prank(owner);
        token.mint(amount);

        assertEq(token.balanceOf(owner), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testMintIncreasesTotalSupply(uint256 amount) public {
        vm.assume(amount > 0);

        uint256 initialSupply = token.totalSupply();
        vm.prank(owner);
        token.mint(amount);
        uint256 finalSupply = token.totalSupply();

        assertEq(finalSupply, initialSupply + amount);
    }

    function testConstructorInitializesCorrectly() public view {
        assertEq(token.name(), "Real Estate Token");
        assertEq(token.symbol(), "RET");
        assertEq(token.owner(), owner);
        assertEq(token.totalSupply(), 0);
    }
}
