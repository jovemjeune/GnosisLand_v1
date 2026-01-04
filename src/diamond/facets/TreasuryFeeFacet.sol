// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibTreasuryStorage} from "../libraries/LibTreasuryStorage.sol";
import {IEscrowNFT} from "../../interfaces/IEscrowNFT.sol";
import {TreasuryStakingLibrary} from "../../libraries/TreasuryStakingLibrary.sol";

interface ITreasuryStakingFacet {
    function stakeAssets(uint256 amount, address staker, bool isReferral) external;
}

contract TreasuryFeeFacet {
    using SafeERC20 for IERC20;

    error invalidAmount();
    error contractPaused();
    error unauthorizedCaller();
    error zeroAddress();

    event TreasuryFeeReceived(uint256 amount);
    event ReferralRewardStaked(
        address indexed referrer, address indexed referred, uint256 rewardAmount, uint256 sharesMinted
    );
    event GlUSDPaymentProcessed(address indexed from, address indexed to, uint256 amount);
    event AssetsStaked(address indexed protocol, uint256 amount);

    function receiveTreasuryFee(
        uint256 amount,
        address,
        address,
        bytes32,
        uint256 referralReward,
        address referrer
    ) external {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        if (ts.paused) revert contractPaused();
        if (msg.sender != ts.lessonNFT) revert unauthorizedCaller();
        if (amount == 0) revert invalidAmount();

        emit TreasuryFeeReceived(amount);

        if (referralReward > 0 && referrer != address(0)) {
            _processReferralReward(referralReward, referrer);
        }

        bool hasReferral = (referralReward > 0 && referrer != address(0));

        if (hasReferral) {
            ts.protocolFunds += amount;
        } else {
            uint256 protocolFee = amount / 2;
            uint256 stakerFee = amount / 2;
            ts.protocolFunds += protocolFee;
            // Call staking function via diamond
            ITreasuryStakingFacet(address(this)).stakeAssets(stakerFee, address(this), false);
        }
    }

    function _processReferralReward(uint256 referralReward, address referrer) internal {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        ts.underlyingBalanceOf[referrer] += referralReward;
        ts.referrerStakedCollateral[referrer] += referralReward;
        uint256 shares = referralReward;
        ts.referrerShares[referrer] += shares;
        ts.referrerTotalRewards[referrer] += referralReward;
        ts.totalShares += shares;
        ts.glusdToken.mint(referrer, shares);
        emit ReferralRewardStaked(referrer, address(0), referralReward, shares);
    }

    function validateReferralCode(bytes32 referralCode) public view returns (address referrer, uint256 tokenId) {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        if (ts.escrowNFT == address(0)) {
            return (address(0), 0);
        }
        return IEscrowNFT(ts.escrowNFT).validateReferralCode(referralCode);
    }

    function handleGlUSDPayment(uint256 glusdAmount, address from, address to) external returns (bool) {
        LibTreasuryStorage.TreasuryStorage storage ts = LibTreasuryStorage.treasuryStorage();
        if (ts.paused) revert contractPaused();
        if (msg.sender != ts.lessonNFT) revert unauthorizedCaller();
        if (glusdAmount == 0) revert invalidAmount();
        if (from == address(0) || to == address(0)) revert zeroAddress();
        IERC20(address(ts.glusdToken)).safeTransferFrom(from, to, glusdAmount);
        emit GlUSDPaymentProcessed(from, to, glusdAmount);
        return true;
    }

    // Getters
    function referrerStakedCollateral(address referrer) external view returns (uint256) {
        return LibTreasuryStorage.treasuryStorage().referrerStakedCollateral[referrer];
    }

    function referrerShares(address referrer) external view returns (uint256) {
        return LibTreasuryStorage.treasuryStorage().referrerShares[referrer];
    }

    function referrerTotalRewards(address referrer) external view returns (uint256) {
        return LibTreasuryStorage.treasuryStorage().referrerTotalRewards[referrer];
    }

    function protocolFunds() external view returns (uint256) {
        return LibTreasuryStorage.treasuryStorage().protocolFunds;
    }

}

