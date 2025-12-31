// SPDX-License-Identifier: MIT

//  ____                 _       _                    _
// / ___|_ __   ___  ___(_)___  | |    __ _ _ __   __| |
//| |  _| '_ \ / _ \/ __| / __| | |   / _` | '_ \ / _` |
//| |_| | | | | (_) \__ \ \__ \ | |__| (_| | | | | (_| |
// \____|_| |_|\___/|___/_|___/ |_____\__,_|_| |_|\__,_|

pragma solidity ^0.8.13;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Vault
 * @dev ERC4626 vault for staking GlUSD to earn yield
 * @notice Users deposit GlUSD to earn interest. Only users who stake are eligible for yield.
 * @notice On withdraw, GlUSD is burned from Treasury instead of being sent back to user.
 * @notice Protected against donation attacks via virtual shares.
 * @notice NON-UPGRADEABLE for maximum security (uses battle-tested OpenZeppelin ERC4626)
 */
contract Vault is ERC4626, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    //-----------------------Storage Variables-----------------------------------------
    address public treasuryContract; // Treasury contract address
    uint256 private _virtualShares; // Virtual shares to prevent donation attacks
    uint256 private _virtualAssets; // Virtual assets to prevent donation attacks

    // Track user shares in vault (GlUSD deposited to vault)
    mapping(address => uint256) public GlUSD_shareOf; // User => GlUSD shares in vault

    //-----------------------constants-----------------------------------------
    uint256 private constant INITIAL_VIRTUAL_SHARES = 1e18; // 1 share to prevent donation attacks
    uint256 private constant INITIAL_VIRTUAL_ASSETS = 1e18; // 1 asset to prevent donation attacks

    //-----------------------custom errors-----------------------------------------
    error zeroAddress();
    error unauthorizedCaller();
    error insufficientBalance();
    error invalidAmount();

    //-----------------------events-----------------------------------------
    event GlUSDBurned(address indexed user, uint256 amount);
    event SharesTracked(address indexed user, uint256 shares);

    //-----------------------constructor-----------------------------------------
    /**
     * @notice Initializes the Vault contract
     * @dev Sets up GlUSD as asset, virtual shares for donation attack protection, and owner
     * @param _glusdToken Address of the GlUSD token (asset)
     * @param _treasuryContract Address of the TreasuryContract
     * @param initialOwner Address of the initial owner
     * @custom:reverts zeroAddress If any address parameter is address(0)
     * @custom:security Non-upgradeable for maximum security
     */
    constructor(address _glusdToken, address _treasuryContract, address initialOwner)
        ERC4626(IERC20(_glusdToken))
        ERC20("", "")
        Ownable(initialOwner)
    {
        if (_glusdToken == address(0) || _treasuryContract == address(0) || initialOwner == address(0)) {
            revert zeroAddress();
        }

        treasuryContract = _treasuryContract;
        _virtualShares = INITIAL_VIRTUAL_SHARES;
        _virtualAssets = INITIAL_VIRTUAL_ASSETS;

        // Mint initial virtual shares to prevent donation attacks
        _mint(address(this), INITIAL_VIRTUAL_SHARES);
    }

    //-----------------------ERC20 overrides-----------------------------------------
    /**
     * @notice Returns the name of the vault token
     * @dev Overrides ERC20 name()
     * @return Name of the vault token
     */
    function name() public pure override(ERC20, IERC20Metadata) returns (string memory) {
        return "Vault GlUSD";
    }

    /**
     * @notice Returns the symbol of the vault token
     * @dev Overrides ERC20 symbol()
     * @return Symbol of the vault token
     */
    function symbol() public pure override(ERC20, IERC20Metadata) returns (string memory) {
        return "vGlUSD";
    }

    //-----------------------public view functions-----------------------------------------
    /**
     * @notice Returns total assets managed by vault (including virtual assets)
     * @dev Overrides ERC4626 totalAssets() to include virtual assets for donation attack protection
     * @return Total assets including virtual assets
     */
    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this)) + _virtualAssets;
    }

    /**
     * @notice Returns total shares (including virtual shares)
     * @dev Overrides ERC20 totalSupply() to include virtual shares for donation attack protection
     * @return Total shares including virtual shares
     */
    function totalSupply() public view override(ERC20, IERC20) returns (uint256) {
        return super.totalSupply() + _virtualShares;
    }

    /**
     * @notice Converts assets to shares (with virtual protection)
     * @dev Overrides ERC4626 conversion to account for virtual shares/assets
     * @param assets Amount of assets to convert
     * @return shares Amount of shares equivalent
     */
    function convertToShares(uint256 assets) public view override returns (uint256 shares) {
        uint256 supply = super.totalSupply();
        if (supply == 0 || totalAssets() == 0) {
            return assets; // 1:1 initially
        }
        return assets.mulDiv(super.totalSupply() + _virtualShares, totalAssets(), Math.Rounding.Floor);
    }

    /**
     * @notice Converts shares to assets (with virtual protection)
     * @dev Overrides ERC4626 conversion to account for virtual shares/assets
     * @param shares Amount of shares to convert
     * @return assets Amount of assets equivalent
     */
    function convertToAssets(uint256 shares) public view override returns (uint256 assets) {
        uint256 supply = super.totalSupply();
        if (supply == 0 || totalAssets() == 0) {
            return shares; // 1:1 initially
        }
        return shares.mulDiv(totalAssets(), super.totalSupply() + _virtualShares, Math.Rounding.Floor);
    }

    //-----------------------external functions-----------------------------------------
    /**
     * @notice Deposits GlUSD into vault
     * @dev Overrides ERC4626 deposit to track user shares
     * @param assets Amount of GlUSD to deposit
     * @param receiver Address to receive vault shares
     * @return shares Amount of vault shares minted
     * @custom:security Protected by reentrancy guard
     * @custom:reverts invalidAmount If assets is 0
     */
    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256 shares) {
        if (assets == 0) {
            revert invalidAmount();
        }

        shares = super.deposit(assets, receiver);

        // Track user's GlUSD shares in vault
        GlUSD_shareOf[receiver] += shares;

        // Notify Treasury to track the shares
        ITreasuryContract(treasuryContract).trackGlUSDShare(receiver, shares);

        emit SharesTracked(receiver, shares);
        return shares;
    }

    /**
     * @notice Withdraws assets from vault (burns GlUSD from Treasury)
     * @dev Overrides ERC4626 withdraw to burn GlUSD from Treasury instead of sending back
     * @param assets Amount of assets (USDC value) to withdraw
     * @param receiver Address to receive USDC
     * @param owner Address that owns the shares
     * @return shares Amount of shares burned
     * @custom:security Protected by reentrancy guard
     * @custom:reverts insufficientBalance If owner doesn't have enough shares
     */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        nonReentrant
        returns (uint256 shares)
    {
        shares = previewWithdraw(assets);

        if (shares > balanceOf(owner)) {
            revert insufficientBalance();
        }

        // Burn shares from owner
        _burn(owner, shares);

        // Update tracked shares
        if (GlUSD_shareOf[owner] >= shares) {
            GlUSD_shareOf[owner] -= shares;
        } else {
            GlUSD_shareOf[owner] = 0; // Prevent underflow
        }

        // Instead of sending GlUSD back, request Treasury to burn it and send USDC
        // Treasury will handle the conversion and USDC transfer
        // Pass assets (GlUSD amount) not shares (vault shares) to handleVaultWithdraw
        ITreasuryContract(treasuryContract).handleVaultWithdraw(owner, assets, assets, receiver);

        emit Withdraw(_msgSender(), receiver, owner, assets, shares);
        return shares;
    }

    /**
     * @notice Redeems shares for assets (burns GlUSD from Treasury)
     * @dev Overrides ERC4626 redeem to burn GlUSD from Treasury
     * @param shares Amount of shares to redeem
     * @param receiver Address to receive USDC
     * @param owner Address that owns the shares
     * @return assets Amount of assets (USDC) received
     * @custom:security Protected by reentrancy guard
     */
    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        nonReentrant
        returns (uint256 assets)
    {
        assets = previewRedeem(shares);

        if (shares > balanceOf(owner)) {
            revert insufficientBalance();
        }

        // Burn shares from owner
        _burn(owner, shares);

        // Update tracked shares
        if (GlUSD_shareOf[owner] >= shares) {
            GlUSD_shareOf[owner] -= shares;
        } else {
            GlUSD_shareOf[owner] = 0; // Prevent underflow
        }

        // Instead of sending GlUSD back, request Treasury to burn it and send USDC
        // Pass assets (GlUSD amount) not shares (vault shares) to handleVaultWithdraw
        ITreasuryContract(treasuryContract).handleVaultWithdraw(owner, assets, assets, receiver);

        emit Withdraw(_msgSender(), receiver, owner, assets, shares);
        return assets;
    }

    /**
     * @notice Updates treasury contract address
     * @dev Only owner can update
     * @param _newTreasury Address of the new TreasuryContract
     * @custom:security Only callable by owner
     * @custom:reverts zeroAddress If new treasury address is address(0)
     */
    function updateTreasury(address _newTreasury) external onlyOwner {
        if (_newTreasury == address(0)) {
            revert zeroAddress();
        }
        treasuryContract = _newTreasury;
    }
}

// Interface for TreasuryContract
interface ITreasuryContract {
    function handleVaultWithdraw(address user, uint256 glusdShares, uint256 usdcAmount, address receiver) external;
    function trackGlUSDShare(address user, uint256 shares) external;
}
