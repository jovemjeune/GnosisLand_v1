// SPDX-License-Identifier: MIT

//  ____                 _       _                    _
// / ___|_ __   ___  ___(_)___  | |    __ _ _ __   __| |
//| |  _| '_ \ / _ \/ __| / __| | |   / _` | '_ \ / _` |
//| |_| | | | | (_) \__ \ \__ \ | |__| (_| | | | | (_| |
// \____|_| |_|\___/|___/_|___/ |_____\__,_|_| |_|\__,_|

pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract gUSD{
    /**
    *@title gUSD
    *@dev Governance USD token
    *@notice Governance USD token is a token that is used to vote on the governance of the project.
    *@notice It is minted to the caller by sending enough underlying tokens to the voting contract.
    *@notice It can be transferred only to the voting contract or the zero address.
    */  
    using SafeERC20 for ERC20;

    uint256 price;
    uint256 minimumDeposit; 
    erc20 underlyingToken;
    uint256 decimalMultiplier;
    address votingContract;

    constructor(address _token, address _votingContract) 
    Ownable(msg.sender) 
    ERC20("Governance USD","gUSD"){
        price = 2e16;
        underlyingToken = IERC20(_token);
        minimumDeposit = 2e16;
        decimalMultiplier = 1e16;
        votingContract = _votingContract;
    }

    //**
    /** @dev Changes the price of the governance token.
    /** @param newPrice The new price of the governance token
    */
    function setPrice(uint256 newPrice) external onlyOwner{
        require(newPrice > 0, "Cannot be zero");
        price = newPrice;
    }
    
    //**
    /** @dev Changes the decimal multiplier.
    /** @param _decimalMultiplier The new decimal multiplier
    */
    function setDecimalMultiplier(uint256 _decimalMultiplier) onlyOwner{
        require(_decimalMultiplier > 0, "Cannot be zero");
        decimalMultiplier = _decimalMultiplier;
    }
    
    /**   
    *@dev Changes the voting contract address.
    *@param newVotingContract The new voting contract address
    */
    function setVotingContract(address newVotingContract) external onlyOwner{
        require(newVotingContract != address(0), "Zero Address Detected!");
        votingContract = newVotingContract;
    }

    //**
    /** @dev Mints governance tokens to the caller by checking if caller send 
    enough underlying tokens to the voting contract.
    /** @param _amount The amount of underlying tokens to be deposited
    */
    function mint(uint256 _amount) external{
        require(_amount >= minimumDeposit,"Amount is lower then minimumDeposit!");
        underlyingToken.safeTransferFrom(msg.sender, votingContract,_amount);
        amountToBeMinted = _amount * decimalMultiplier / price; 
        _safeMint(msg.sender, amountToBeMinted);
    }

    //**
    /** @dev 0verrides the update function to ensure governanceTokens
    can be minted to any address but can be transferred only to the voting contract 
    or the zero address.
     */
    function _update(address from, 
                    address to, 
                    uint256 amount
    ) internal virtual override{
    if((from != address(0)) && ((to != votingContract) || (to != address(0)))) revert();
    super._update(from,to,amount);
    }
}