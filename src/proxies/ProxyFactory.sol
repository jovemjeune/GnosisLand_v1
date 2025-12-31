// SPDX-License-Identifier: MIT

//  ____                 _       _                    _
// / ___|_ __   ___  ___(_)___  | |    __ _ _ __   __| |
//| |  _| '_ \ / _ \/ __| / __| | |   / _` | '_ \ / _` |
//| |_| | | | | (_) \__ \ \__ \ | |__| (_| | | | | (_| |
// \____|_| |_|\___/|___/_|___/ |_____\__,_|_| |_|\__,_|

pragma solidity ^0.8.13;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LessonNFT} from "../LessonNFT.sol";
import {TeacherNft} from "../TeacherNFT.sol";
import {DiscountBallot} from "../DiscountBallot.sol";
import {EscrowNFT} from "../EscrowNFT.sol";
import {GlUSD} from "../GlUSD.sol";
import {TreasuryContract} from "../TreasuryContract.sol";

/**
 * @title ProxyFactory
 * @dev Factory contract for deploying UUPS proxies
 * @notice This factory deploys ERC1967Proxy directly (UUPS pattern doesn't require custom proxy contracts)
 */
contract ProxyFactory {
    event LessonNFTProxyDeployed(address indexed proxy, address indexed implementation);
    event TeacherNFTProxyDeployed(address indexed proxy, address indexed implementation);
    event DiscountBallotProxyDeployed(address indexed proxy, address indexed implementation);
    event EscrowNFTProxyDeployed(address indexed proxy, address indexed implementation);
    event GlUSDProxyDeployed(address indexed proxy, address indexed implementation);
    event TreasuryContractProxyDeployed(address indexed proxy, address indexed implementation);

    /**
     * @dev Deploys a LessonNFT proxy with the given implementation and initialization parameters
     * @param implementation The address of the LessonNFT implementation contract
     * @param factory The factory address (will be set as owner)
     * @param onBehalf The teacher's account address
     * @param treasuryContract The treasury contract address for fees
     * @param paymentToken The payment token address (e.g., USDC)
     * @param teacherNFT The TeacherNFT contract address
     * @param certificateFactory The CertificateFactory contract address (can be address(0))
     * @param price The initial price for lessons
     * @param name The NFT collection name
     * @param data Additional data for NFT minting
     * @return proxy The address of the deployed proxy contract
     */
    function deployLessonNFTProxy(
        address implementation,
        address factory,
        address onBehalf,
        address treasuryContract,
        address paymentToken,
        address teacherNFT,
        address certificateFactory,
        uint256 price,
        string memory name,
        bytes memory data
    ) external returns (address proxy) {
        bytes memory initData = abi.encodeWithSelector(
            LessonNFT.initialize.selector,
            factory,
            onBehalf,
            treasuryContract,
            paymentToken,
            teacherNFT,
            certificateFactory,
            price,
            name,
            data
        );

        proxy = address(new ERC1967Proxy(implementation, initData));
        emit LessonNFTProxyDeployed(proxy, implementation);
    }

    /**
     * @dev Deploys a TeacherNFT proxy with the given implementation and initialization parameters
     * @param implementation The address of the TeacherNFT implementation contract
     * @param name The NFT collection name
     * @param symbol The NFT collection symbol
     * @param initialOwner The initial owner address
     * @return proxy The address of the deployed proxy contract
     */
    function deployTeacherNFTProxy(
        address implementation,
        string memory name,
        string memory symbol,
        address initialOwner
    ) external returns (address proxy) {
        bytes memory initData = abi.encodeWithSelector(TeacherNft.initialize.selector, name, symbol, initialOwner);

        proxy = address(new ERC1967Proxy(implementation, initData));
        emit TeacherNFTProxyDeployed(proxy, implementation);
    }

    /**
     * @dev Deploys a DiscountBallot proxy with the given implementation and initialization parameters
     * @param implementation The address of the DiscountBallot implementation contract
     * @param minimumDepositPerVote The minimum deposit required per vote
     * @param initialOwner The initial owner address
     * @return proxy The address of the deployed proxy contract
     */
    function deployDiscountBallotProxy(address implementation, uint256 minimumDepositPerVote, address initialOwner)
        external
        returns (address proxy)
    {
        bytes memory initData =
            abi.encodeWithSelector(DiscountBallot.initialize.selector, minimumDepositPerVote, initialOwner);

        proxy = address(new ERC1967Proxy(implementation, initData));
        emit DiscountBallotProxyDeployed(proxy, implementation);
    }

    /**
     * @dev Deploys an EscrowNFT proxy
     * @param implementation The address of the EscrowNFT implementation contract
     * @param initialOwner The initial owner address
     * @return proxy The address of the deployed proxy contract
     */
    function deployEscrowNFTProxy(address implementation, address initialOwner) external returns (address proxy) {
        bytes memory initData = abi.encodeWithSelector(EscrowNFT.initialize.selector, initialOwner);

        proxy = address(new ERC1967Proxy(implementation, initData));
        emit EscrowNFTProxyDeployed(proxy, implementation);
    }

    /**
     * @dev Deploys a GlUSD proxy
     * @param implementation The address of the GlUSD implementation contract
     * @param treasuryContract The treasury contract address
     * @param usdcToken The USDC token address
     * @param initialOwner The initial owner address
     * @return proxy The address of the deployed proxy contract
     */
    function deployGlUSDProxy(address implementation, address treasuryContract, address usdcToken, address initialOwner)
        external
        returns (address proxy)
    {
        bytes memory initData =
            abi.encodeWithSelector(GlUSD.initialize.selector, treasuryContract, usdcToken, initialOwner);

        proxy = address(new ERC1967Proxy(implementation, initData));
        emit GlUSDProxyDeployed(proxy, implementation);
    }

    /**
     * @dev Deploys a TreasuryContract proxy
     * @param implementation The address of the TreasuryContract implementation contract
     * @param glusdToken The GlUSD token address
     * @param usdcToken The USDC token address
     * @param aavePool The Aave Pool address
     * @param morphoMarket The Morpho Market address
     * @param escrowNFT The EscrowNFT address
     * @param lessonNFT The LessonNFT address (for access control)
     * @param initialOwner The initial owner address
     * @return proxy The address of the deployed proxy contract
     */
    function deployTreasuryContractProxy(
        address implementation,
        address glusdToken,
        address usdcToken,
        address aavePool,
        address morphoMarket,
        address escrowNFT,
        address lessonNFT,
        address initialOwner
    ) external returns (address proxy) {
        bytes memory initData = abi.encodeWithSelector(
            TreasuryContract.initialize.selector,
            glusdToken,
            usdcToken,
            aavePool,
            morphoMarket,
            escrowNFT,
            lessonNFT,
            initialOwner
        );

        proxy = address(new ERC1967Proxy(implementation, initData));
        emit TreasuryContractProxyDeployed(proxy, implementation);
    }
}
