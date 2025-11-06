// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract ALONEAStaking is Initializable, UUPSUpgradeable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    
    IERC20Upgradeable public stakingToken;
    
    enum Tier { Free, Bronze, Silver, Platinum, Diamond }
    
    struct TierInfo {
        uint256 minStake;
        uint256 multiplier; // In basis points (10000 = 1x)
    }
    
    struct Staker {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastStakeTime;
        Tier tier;
    }
    
    mapping(Tier => TierInfo) public tiers;
    mapping(address => Staker) public stakers;
    
    uint256 public totalStaked;
    uint256 public rewardRate; // Rewards per second per token
    uint256 public accRewardPerShare;
    uint256 public lastUpdateTime;
    
    event Staked(address indexed user, uint256 amount, Tier tier);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event TierUpdated(Tier tier, uint256 minStake, uint256 multiplier);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _stakingToken, address initialOwner) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(initialOwner);
        __ReentrancyGuard_init();
        
        stakingToken = IERC20Upgradeable(_stakingToken);
        
        // Initialize tiers
        tiers[Tier.Free] = TierInfo(0, 10000);
        tiers[Tier.Bronze] = TierInfo(100 * 10**18, 10000);
        tiers[Tier.Silver] = TierInfo(500 * 10**18, 11000);
        tiers[Tier.Platinum] = TierInfo(1000 * 10**18, 12500);
        tiers[Tier.Diamond] = TierInfo(1500 * 10**18, 15000);
        
        rewardRate = 3170979198; // ~10% APY assuming 100M supply
        lastUpdateTime = block.timestamp;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function updateRewards() public {
        if (totalStaked > 0) {
            uint256 timePassed = block.timestamp - lastUpdateTime;
            uint256 rewards = timePassed * rewardRate;
            accRewardPerShare += (rewards * 1e18) / totalStaked;
        }
        lastUpdateTime = block.timestamp;
    }

    function stake(uint256 amount) external nonReentrant {
        updateRewards();
        
        Staker storage staker = stakers[msg.sender];
        
        if (staker.amount > 0) {
            uint256 pending = pendingRewards(msg.sender);
            if (pending > 0) {
                stakingToken.safeTransfer(msg.sender, pending);
                emit RewardClaimed(msg.sender, pending);
            }
        }
        
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        
        staker.amount += amount;
        staker.rewardDebt = (staker.amount * accRewardPerShare) / 1e18;
        staker.lastStakeTime = block.timestamp;
        
        // Update tier
        Tier newTier = getTierForAmount(staker.amount);
        staker.tier = newTier;
        
        totalStaked += amount;
        
        emit Staked(msg.sender, amount, newTier);
    }

    function unstake(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        
        updateRewards();
        
        Staker storage staker = stakers[msg.sender];
        require(staker.amount >= amount, "Insufficient staked amount");
        
        uint256 pending = pendingRewards(msg.sender);
        if (pending > 0) {
            stakingToken.safeTransfer(msg.sender, pending);
            emit RewardClaimed(msg.sender, pending);
        }
        
        staker.amount -= amount;
        staker.rewardDebt = (staker.amount * accRewardPerShare) / 1e18;
        
        // Update tier
        Tier newTier = getTierForAmount(staker.amount);
        staker.tier = newTier;
        
        totalStaked -= amount;
        
        stakingToken.safeTransfer(msg.sender, amount);
        
        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external nonReentrant {
        updateRewards();
        
        Staker storage staker = stakers[msg.sender];
        uint256 pending = pendingRewards(msg.sender);
        
        require(pending > 0, "No rewards to claim");
        
        staker.rewardDebt = (staker.amount * accRewardPerShare) / 1e18;
        
        stakingToken.safeTransfer(msg.sender, pending);
        
        emit RewardClaimed(msg.sender, pending);
    }

    function emergencyWithdraw() external nonReentrant {
        Staker storage staker = stakers[msg.sender];
        uint256 amount = staker.amount;
        
        require(amount > 0, "No staked tokens");
        
        totalStaked -= amount;
        staker.amount = 0;
        staker.rewardDebt = 0;
        staker.tier = Tier.Free;
        
        stakingToken.safeTransfer(msg.sender, amount);
        
        emit EmergencyWithdraw(msg.sender, amount);
    }

    function pendingRewards(address user) public view returns (uint256) {
        Staker storage staker = stakers[user];
        
        if (staker.amount == 0) return 0;
        
        uint256 currentAccRewardPerShare = accRewardPerShare;
        if (totalStaked > 0) {
            uint256 timePassed = block.timestamp - lastUpdateTime;
            uint256 rewards = timePassed * rewardRate;
            currentAccRewardPerShare += (rewards * 1e18) / totalStaked;
        }
        
        uint256 pending = (staker.amount * currentAccRewardPerShare) / 1e18 - staker.rewardDebt;
        uint256 multiplier = tiers[staker.tier].multiplier;
        
        return (pending * multiplier) / 10000;
    }

    function getTierForAmount(uint256 amount) public view returns (Tier) {
        if (amount >= tiers[Tier.Diamond].minStake) return Tier.Diamond;
        if (amount >= tiers[Tier.Platinum].minStake) return Tier.Platinum;
        if (amount >= tiers[Tier.Silver].minStake) return Tier.Silver;
        if (amount >= tiers[Tier.Bronze].minStake) return Tier.Bronze;
        return Tier.Free;
    }

    function updateTier(Tier tier, uint256 minStake, uint256 multiplier) external onlyOwner {
        tiers[tier] = TierInfo(minStake, multiplier);
        emit TierUpdated(tier, minStake, multiplier);
    }

    function updateRewardRate(uint256 newRewardRate) external onlyOwner {
        updateRewards();
        rewardRate = newRewardRate;
    }

    function version() public pure returns (string memory) {
        return "1.0.0";
    }
}
