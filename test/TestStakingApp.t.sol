// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "../src/StakingApp.sol";
import "../src/RealEstateToken.sol";
import "../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract TestStakingApp is Test {
    StakingApp stakingApp;
    RealEstateToken RET;
    RealEstateToken USDC;

    address owner = address(0xA11CE1);
    address randomUser = vm.addr(2);
    address attacker = vm.addr(3);

    function setUp() external {
        //Deploy RET and USDC tokens
        vm.prank(owner);
        RET = new RealEstateToken("Real Estate Token", "RET", owner);
        vm.prank(owner);
        USDC = new RealEstateToken("USD Coin", "USDC", owner);

        //Depoly StakingApp
        vm.prank(owner);
        stakingApp = new StakingApp(address(RET), address(USDC), owner);

        // Mint tokens to user for testing
        vm.startPrank(owner);
        RET.mint(1000000 ether);
        USDC.mint(1000000 ether);
        vm.stopPrank();

        //Transfer RET to user
        vm.prank(owner);
        RET.transfer(randomUser, 1000 ether);

        //Approve stakingcontract
        vm.prank(randomUser);
        RET.approve(address(stakingApp), type(uint256).max);
    }

    //__________________________________________________
    //FUZZ: ADD PROPERTY
    //--------------------------------------------------

    function testAddProperty(uint256 rewardRateBps_) public {
        vm.assume(rewardRateBps_ <= 10000);

        vm.prank(owner);
        stakingApp.addProperty(rewardRateBps_); // 50% reward rate

        (, , uint256 rewardRateBps) = stakingApp.properties(1);

        assertEq(rewardRateBps, rewardRateBps_); // _ indica la variable almacenada en el storage del contrato
    }

    //__________________________________________________
    // NEGATIVE TEST: ADD PROPERTY
    //--------------------------------------------------

    function testNonOwnerCannotAddProperty() public {
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                attacker
            )
        );

        stakingApp.addProperty(5000);
    }

    //__________________________________________________
    // FUZZ: UPDATE PROPERTY
    //--------------------------------------------------

    function testUpdateProperty(bool success, uint256 rewardRateBps_) public {
        vm.assume(rewardRateBps_ <= 10000);

        vm.prank(owner);
        stakingApp.addProperty(5000); // 50% reward rate

        vm.prank(owner);
        stakingApp.updateProperty(1, success, rewardRateBps_); // Update to successful with 60% reward rate

        (, bool successful_, uint256 rate_) = stakingApp.properties(1);

        assertEq(successful_, success);
        assertEq(rate_, rewardRateBps_);
    }

    //__________________________________________________
    // NEGATIVE TEST: UPDATE PROPERTY REVERTS IF NOT EXIST
    //--------------------------------------------------

    function testUpdatePropertyRevertsIfNotExist() public {
        vm.prank(owner);
        vm.expectRevert("Property does not exist");
        stakingApp.updateProperty(1, true, 6000);
    }

    //__________________________________________________
    // NEGATIVE TEST: UPDATE PROPERTY REVERTS IF INVALID REWARD RATE
    //--------------------------------------------------
    function testUpdatePropertyRevertsIfInvalidRewardRate() public {
        vm.prank(owner);
        stakingApp.addProperty(5000); // 50% reward rate

        vm.prank(owner);
        vm.expectRevert(
            "Invalid amount. The amount must be 100% of your invested amount per period."
        );
        stakingApp.updateProperty(1, true, 15000); // Invalid reward rate
    }

    //__________________________________________________
    // FUZZ: DEPOSIT TOKENS
    //--------------------------------------------------
    function testDepositTokens(uint256 fuzzAmount) public {
        vm.assume(fuzzAmount > 0 && fuzzAmount <= 1000 ether);

        //Add property
        vm.prank(owner);
        stakingApp.addProperty(5000); // 50% reward rate

        //Deposit
        vm.prank(randomUser);
        stakingApp.depositTokens(1, fuzzAmount);

        (uint256 storedAmount, , ) = stakingApp.stakes(randomUser, 1);

        assertEq(storedAmount, fuzzAmount);
    }

    //__________________________________________________
    // FUZZ NEGATIVE TEST: DEPOSIT TOKENS REVERTS IF PROPERTY NOT EXIST
    //--------------------------------------------------
    function testDepositRevertsIfPropertyNotExist(uint256 fuzzAmount) public {
        vm.assume(fuzzAmount > 0 && fuzzAmount <= 1000 ether);

        vm.prank(randomUser);
        vm.expectRevert("Property does not exist");
        stakingApp.depositTokens(1, fuzzAmount);
    }

    //__________________________________________________
    // FUZZ: WITHDRRAW TOKENS
    //--------------------------------------------------
    function testWithdrawTokens(uint256 fuzzAmount) public {
        uint256 initialDeposit = 1000 ether;

        vm.assume(fuzzAmount > 0 && fuzzAmount <= 300 ether);

        //Add property
        vm.prank(owner);
        stakingApp.addProperty(5000); // 50% reward rate

        //Deposit
        vm.prank(randomUser);
        stakingApp.depositTokens(1, initialDeposit);

        //Wait staking period
        vm.warp(block.timestamp + stakingApp.stakingPeriod());

        //Withdraw
        vm.prank(randomUser);
        stakingApp.withdrawTokens(1, fuzzAmount);

        //Check remaining stake
        (uint256 storedAmount, , ) = stakingApp.stakes(randomUser, 1);

        assertEq(storedAmount, initialDeposit - fuzzAmount);
    }

    //__________________________________________________
    // FUZZ NEGATIVE TEST: WITHDRAW TOKENS REVERTS IF:
    //--------------------------------------------------

    function testWithdrawRevertsIfPropertyNotExist() public {
        vm.prank(randomUser);
        vm.expectRevert("Property does not exist.");
        stakingApp.withdrawTokens(999, 10 ether);
    }

    function testWithdrawRevertsIfamountIsLessThanOrEqualToZero() public {
        vm.prank(owner);
        stakingApp.addProperty(5000); // 50% reward rate

        vm.prank(randomUser);
        vm.expectRevert("Amount must be > 0.");
        stakingApp.withdrawTokens(1, 0);
    }

    function testWithdrawRevertsIfInsufficientBalance(
        uint256 depositAmount_,
        uint256 withdrawAmount_
    ) public {
        vm.assume(depositAmount_ > 0 && depositAmount_ <= 1000 ether);
        vm.assume(withdrawAmount_ > depositAmount_);

        //Add property
        vm.prank(owner);
        stakingApp.addProperty(5000); // 50% reward rate

        //Deposit
        vm.prank(randomUser);
        stakingApp.depositTokens(1, depositAmount_);

        //Wait staking period
        vm.warp(block.timestamp + stakingApp.stakingPeriod());

        //Withdraw
        vm.prank(randomUser);
        vm.expectRevert("Insufficient balance.");
        stakingApp.withdrawTokens(1, withdrawAmount_);
    }

    function testWithdrawRevertsIfPeriodNotEnded() public {
        vm.prank(owner);
        stakingApp.addProperty(5000); // 50% reward rate

        vm.prank(randomUser);
        stakingApp.depositTokens(1, 500 ether);

        vm.prank(randomUser);
        vm.expectRevert("Must wait full staking period.");
        stakingApp.withdrawTokens(1, 500 ether);
    }

    function testWithdrawRevertsIfExceedsMaxWithdraw() public {
        uint256 initialDeposit = 1000 ether;
        uint256 withdrawAmount_ = 400 ether;
        vm.assume(withdrawAmount_ > (initialDeposit * 30) / 100);

        //Add property
        vm.prank(owner);
        stakingApp.addProperty(5000); // 50% reward rate

        //Deposit
        vm.prank(randomUser);
        stakingApp.depositTokens(1, initialDeposit);

        //Wait staking period
        vm.warp(block.timestamp + stakingApp.stakingPeriod());

        //Withdraw
        vm.prank(randomUser);
        vm.expectRevert(
            "Withdraw amount exceeds allowed limit based on reward rate."
        );
        stakingApp.withdrawTokens(1, withdrawAmount_);
    }

    //__________________________________________________
    // FUZZ: TEST CLAIM REWARDS
    //--------------------------------------------------

    function testClaimRewards(uint256 rewardRate_, uint256 fuzzAmount_) public {
        vm.assume(rewardRate_ > 0 && rewardRate_ <= 10000);
        vm.assume(fuzzAmount_ > 0 && fuzzAmount_ <= 1000 ether);

        vm.assume((fuzzAmount_ * rewardRate_) / 10000 > 0); // Ensure rewards are greater than 0

        vm.startPrank(owner);
        stakingApp.addProperty(5000);
        stakingApp.updateProperty(1, true, rewardRate_);
        vm.stopPrank();

        vm.prank(randomUser);
        stakingApp.depositTokens(1, fuzzAmount_);

        //Warp time by staking period
        vm.warp(block.timestamp + stakingApp.stakingPeriod());

        vm.prank(owner);
        USDC.transfer(address(stakingApp), 1000000 ether);

        vm.prank(randomUser);
        stakingApp.claimRewards(1);

        assertGt(USDC.balanceOf(randomUser), 0);
    }

    //__________________________________________________
    // NEGATIVE TEST: TEST CLAIM REWARDS REVERTS IF:
    //--------------------------------------------------

    function testClaimRewardsRevertsIfPropertyNotExist() public {
        vm.prank(randomUser);
        vm.expectRevert("Property not found");
        stakingApp.claimRewards(999);
    }

    function testClaimRewardsRevertsIfPropertyNotSuccessful() public {
        vm.prank(owner);
        stakingApp.addProperty(5000); // Add property but do not set successful

        vm.prank(randomUser);
        vm.expectRevert("Property not successful");
        stakingApp.claimRewards(1);
    }

    function testClaimRewardsRevertsIfNotStaked() public {
        vm.startPrank(owner);
        stakingApp.addProperty(5000);
        stakingApp.updateProperty(1, true, 5000);
        vm.stopPrank();

        vm.prank(randomUser);
        vm.expectRevert("No staked tokens found for user");
        stakingApp.claimRewards(1);
    }

    function testClaimRewardsRevertsIfNotElapsedPeriod() public {
        vm.startPrank(owner);
        stakingApp.addProperty(5000);
        stakingApp.updateProperty(1, true, 5000);
        vm.stopPrank();

        vm.prank(randomUser);
        stakingApp.depositTokens(1, 500 ether);

        vm.prank(randomUser);
        vm.expectRevert(
            "Need to wait until staking period is over to claim rewards"
        );
        stakingApp.claimRewards(1);
    }

    function testClaimRewardsRevertsIfNotRewardsAvailable() public {
        vm.startPrank(owner);
        stakingApp.addProperty(5000);
        stakingApp.updateProperty(1, true, 5000);
        vm.stopPrank();
        vm.prank(randomUser);
        stakingApp.depositTokens(1, 1); // 1 wei

        vm.warp(block.timestamp + stakingApp.stakingPeriod());

        vm.prank(owner);
        USDC.transfer(address(stakingApp), 1000 ether);

        vm.prank(randomUser);
        vm.expectRevert("No rewards available to claim");
        stakingApp.claimRewards(1);
    }

    function testClaimRewardsRevertsIfInsufficientUSDC() public {
        vm.startPrank(owner);
        stakingApp.addProperty(5000);
        stakingApp.updateProperty(1, true, 5000);
        vm.stopPrank();

        vm.prank(randomUser);
        stakingApp.depositTokens(1, 100 ether);

        vm.warp(block.timestamp + stakingApp.stakingPeriod());

        vm.prank(randomUser);
        vm.expectRevert("Insufficient USDC in contract");
        stakingApp.claimRewards(1);
    }
}
