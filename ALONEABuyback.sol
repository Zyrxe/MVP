// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface IUniswapV2Router {
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    
    function WETH() external pure returns (address);
}

contract ALONEABuyback is Initializable, UUPSUpgradeable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    
    IERC20Upgradeable public token;
    IUniswapV2Router public router;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    
    bool public autoBuybackEnabled;
    uint256 public minBalanceForBuyback;
    uint256 public buybackAmount;
    
    event BuybackExecuted(uint256 bnbAmount, uint256 tokenAmount);
    event SettingsUpdated(bool enabled, uint256 minBalance, uint256 buybackAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _token,
        address _router,
        address initialOwner
    ) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(initialOwner);
        __ReentrancyGuard_init();
        
        token = IERC20Upgradeable(_token);
        router = IUniswapV2Router(_router);
        
        autoBuybackEnabled = true;
        minBalanceForBuyback = 1 ether; // 1 BNB
        buybackAmount = 0.1 ether; // 0.1 BNB per buyback
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function executeBuyback() external nonReentrant {
        require(autoBuybackEnabled, "Auto buyback disabled");
        require(address(this).balance >= buybackAmount, "Insufficient BNB balance");
        
        uint256 initialBalance = token.balanceOf(BURN_ADDRESS);
        
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(token);
        
        router.swapExactETHForTokens{value: buybackAmount}(
            0,
            path,
            BURN_ADDRESS,
            block.timestamp
        );
        
        uint256 tokensBurned = token.balanceOf(BURN_ADDRESS) - initialBalance;
        
        emit BuybackExecuted(buybackAmount, tokensBurned);
    }

    function setBuybackSettings(
        bool _enabled,
        uint256 _minBalance,
        uint256 _buybackAmount
    ) external onlyOwner {
        autoBuybackEnabled = _enabled;
        minBalanceForBuyback = _minBalance;
        buybackAmount = _buybackAmount;
        
        emit SettingsUpdated(_enabled, _minBalance, _buybackAmount);
    }

    function withdrawBNB(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(owner()).transfer(amount);
    }

    function withdrawToken(address _token, uint256 amount) external onlyOwner {
        IERC20Upgradeable(_token).safeTransfer(owner(), amount);
    }

    receive() external payable {}

    function version() public pure returns (string memory) {
        return "1.0.0";
    }
}
