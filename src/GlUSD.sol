// SPDX-License-Identifier: MIT

//  ____                 _       _                    _
// / ___|_ __   ___  ___(_)___  | |    __ _ _ __   __| |
//| |  _| '_ \ / _ \/ __| / __| | |   / _` | '_ \ / _` |
//| |_| | | | | (_) \__ \ \__ \ | |__| (_| | | | | (_| |
// \____|_| |_|\___/|___/_|___/ |_____\__,_|_| |_|\__,_|

pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title GlUSD
 * @dev Gnosisland USD - A stablecoin pegged 1:1 with USDC
 * @notice Users can deposit USDC and receive GlUSD at 1:1 ratio
 * @notice GlUSD represents shares in the vault (ERC4626-style)
 */
contract GlUSD is ERC20, Ownable, Initializable, UUPSUpgradeable {
    //-----------------------Storage Variables-----------------------------------------
    address public treasuryContract; // Treasury contract that can mint/burn
    address public usdcToken; // USDC token address

    //-----------------------custom errors-----------------------------------------
    error onlyTreasury();
    error zeroAddress();

    //-----------------------events-----------------------------------------
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    //-----------------------constructor (disabled for upgradeable)-----------------------------------------
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() ERC20("Gnosisland USD", "GlUSD") Ownable(address(this)) {
        _disableInitializers();
    }

    //-----------------------initializer-----------------------------------------
    /**
     * @notice Initializes the GlUSD contract
     * @dev Called once when the proxy is deployed. Sets up treasury and USDC addresses.
     * @param _treasuryContract Address of the TreasuryContract (only authorized minter/burner)
     * @param _usdcToken Address of the USDC token contract
     * @param initialOwner Address of the initial owner
     * @custom:reverts zeroAddress If _treasuryContract or _usdcToken is address(0)
     */
    function initialize(address _treasuryContract, address _usdcToken, address initialOwner) external initializer {
        if (_treasuryContract == address(0) || _usdcToken == address(0)) {
            revert zeroAddress();
        }
        treasuryContract = _treasuryContract;
        usdcToken = _usdcToken;
        _transferOwnership(initialOwner);
    }

    //-----------------------UUPS authorization-----------------------------------------
    /**
     * @notice Authorizes contract upgrades
     * @dev Only the owner can authorize upgrades. This is required by UUPS pattern.
     * @param newImplementation Address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //-----------------------external functions (only treasury)-----------------------------------------
    /**
     * @notice Mints GlUSD tokens
     * @dev Only callable by TreasuryContract. Mints when users deposit USDC.
     * @param to Address to mint tokens to
     * @param amount Amount of GlUSD to mint
     * @custom:security Only callable by TreasuryContract
     * @custom:reverts onlyTreasury If caller is not TreasuryContract
     * @custom:emits Mint When tokens are minted
     */
    function mint(address to, uint256 amount) external {
        if (msg.sender != treasuryContract) {
            revert onlyTreasury();
        }
        _mint(to, amount);
        emit Mint(to, amount);
    }

    /**
     * @notice Burns GlUSD tokens
     * @dev Only callable by TreasuryContract. Burns when users redeem GlUSD for USDC.
     * @param from Address to burn tokens from
     * @param amount Amount of GlUSD to burn
     * @custom:security Only callable by TreasuryContract
     * @custom:reverts onlyTreasury If caller is not TreasuryContract
     * @custom:emits Burn When tokens are burned
     */
    function burn(address from, uint256 amount) external {
        if (msg.sender != treasuryContract) {
            revert onlyTreasury();
        }
        _burn(from, amount);
        emit Burn(from, amount);
    }

    /**
     * @notice Updates the treasury contract address
     * @dev Only owner can update. Used for changing TreasuryContract implementation.
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
