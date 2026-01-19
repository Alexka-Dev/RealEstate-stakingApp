// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract StakingApp is Ownable, ReentrancyGuard {
    //Variables
    address public immutable realEstateToken;
    address public immutable USDCToken;
    uint public stakingPeriod = 7 days;
    uint public rewardPerPeriod;
    uint256 public nextPropertyId = 1;
    struct Property {
        bool exists; // Para validar que la propiedad está registrada
        bool successful; // Indica si la propiedad tuvo éxito (habilita rewards)
        uint256 rewardRateBps; // Tasa de reward por periodo en basis points (10000 = 100%)
    }

    mapping(uint256 => Property) public properties;
    struct StakeInfo {
        uint256 amount; // Monto staked por el usuario en esta propiedad
        uint256 depositedAt; // Último momento relevante para el lock (depósito o retiro)
        uint256 lastClaimAt; // Último momento de claim de rewards
    }
    mapping(address => mapping(uint256 => StakeInfo)) public stakes; // user => property => StakeInfo
    mapping(address => uint) public elapsePeriod;

    //Events
    event Deposit(
        address indexed user,
        uint256 indexed propertyId,
        uint256 amount
    );
    event WithdrawTokens(
        address indexed user,
        uint256 indexed propertyId,
        uint256 amount
    );
    event RewardsClaimed(
        address indexed user,
        uint256 indexed propertyId,
        uint256 rewardAmount
    );
    event PropertyAdded(uint256 indexed propertyId, uint256 rewardRateBps);
    event PropertyUpdated(
        uint256 indexed propertyId,
        bool successful,
        uint256 rewardRateBps
    );
    event StakingPeriodChanged(uint256 newStakingPeriod);

    //Constructor
    constructor(
        address realEstateToken_,
        address USDCToken_,
        address owner_
    ) Ownable(owner_) {
        require(
            realEstateToken_ != address(0),
            "Invalid RealEstateToken address"
        );
        require(USDCToken_ != address(0), "Invalid USDC Token address");

        realEstateToken = realEstateToken_;
        USDCToken = USDCToken_;
    }

    //External Functions

    function addProperty(uint256 rewardRateBps_) external onlyOwner {
        uint256 propertyId_ = nextPropertyId;
        nextPropertyId++;

        properties[propertyId_] = Property({
            exists: true,
            successful: false,
            rewardRateBps: rewardRateBps_
        });

        emit PropertyAdded(propertyId_, rewardRateBps_);
    }

    function updateProperty(
        uint256 propertyId_,
        bool successful_,
        uint256 rewardRateBps_
    ) external onlyOwner {
        Property storage property = properties[propertyId_];
        require(property.exists, "Property does not exist");
        require(
            rewardRateBps_ <= 10000,
            "Invalid amount. The amount must be 100% of your invested amount per period."
        ); //Reward rate must be <= 10000 bps
        property.successful = successful_;
        property.rewardRateBps = rewardRateBps_;

        emit PropertyUpdated(propertyId_, successful_, rewardRateBps_);
    }

    function changeStakingPeriod(uint256 newStakingPeriod_) external onlyOwner {
        require(newStakingPeriod_ > 0, "Invalid period");
        stakingPeriod = newStakingPeriod_;

        emit StakingPeriodChanged(newStakingPeriod_);
    }

    function depositTokens(
        uint256 propertyId_,
        uint256 amount_
    ) external nonReentrant {
        Property memory prop = properties[propertyId_];
        require(prop.exists, "Property does not exist");
        require(amount_ > 0, "Amount must be > 0");

        StakeInfo storage stake = stakes[msg.sender][propertyId_];

        if (stake.amount == 0) {
            stake.depositedAt = 0;
            stake.lastClaimAt = 0;
        } else {
            stake.depositedAt = block.timestamp; //Reset deposit time on additional deposits
        }

        stake.amount += amount_;

        IERC20(realEstateToken).transferFrom(
            msg.sender,
            address(this),
            amount_
        );

        emit Deposit(msg.sender, propertyId_, amount_);
    }

    //Withdraw
    function withdrawTokens(
        uint256 propertyId_,
        uint256 amount_
    ) external nonReentrant {
        Property memory prop = properties[propertyId_];
        require(prop.exists, "Property does not exist.");
        require(amount_ > 0, "Amount must be > 0.");

        StakeInfo storage stake = stakes[msg.sender][propertyId_];
        require(stake.amount >= amount_, "Insufficient balance.");

        require(
            block.timestamp >= stake.depositedAt + stakingPeriod,
            "Must wait full staking period."
        );

        // NEW: Calculate max withdraw BEFORE subtracting
        uint256 maxWithdraw = (stake.amount * 30) / 100;
        require(
            amount_ <= maxWithdraw,
            "Withdraw amount exceeds allowed limit based on reward rate."
        );

        stake.amount -= amount_;

        if (stake.amount > 0) {
            stake.depositedAt = block.timestamp; //Reset deposit time on partial withdrawals
        } else {
            stake.depositedAt = 0;
            stake.lastClaimAt = 0;
        }

        IERC20(realEstateToken).transfer(msg.sender, amount_);

        emit WithdrawTokens(msg.sender, propertyId_, amount_);
    }

    //Claim Rewards
    function claimRewards(uint256 propertyId_) external nonReentrant {
        //Check Balance
        Property memory prop = properties[propertyId_];
        require(prop.exists, "Property not found");
        require(prop.successful, "Property not successful");
        StakeInfo storage stake = stakes[msg.sender][propertyId_];
        require(stake.amount > 0, "No staked tokens found for user");

        //Calculate Rewards Amount
        uint elapsedPeriod_ = block.timestamp - stake.lastClaimAt; //In a real scenario, we would calculate the elapsed time since deposit
        require(
            elapsedPeriod_ >= stakingPeriod,
            "Need to wait until staking period is over to claim rewards"
        );

        uint256 periods = elapsedPeriod_ / stakingPeriod; //Number of complete periods elapsed
        require(periods > 0, "No periods elapsed");

        uint256 rewardPerPeriod_ = (stake.amount * prop.rewardRateBps) / 10000; //Reward per period
        uint256 totalReward = rewardPerPeriod_ * periods;
        require(totalReward > 0, "No rewards available to claim");
        //Update User Balance state
        stake.lastClaimAt += periods * stakingPeriod; //Actualizamos el periodo de staking

        require(
            IERC20(USDCToken).balanceOf(address(this)) >= totalReward,
            "Insufficient USDC in contract"
        );

        //Transfer Rewards
        IERC20(USDCToken).transfer(msg.sender, totalReward);
        emit RewardsClaimed(msg.sender, propertyId_, totalReward);
    }
}
