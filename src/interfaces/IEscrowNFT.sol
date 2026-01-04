interface IEscrowNFT {
    function validateReferralCode(bytes32 referralCode) external view returns (address referrer, uint256 tokenId);
}