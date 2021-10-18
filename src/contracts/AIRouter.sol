// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IDexRouter.sol";
import "./IBEP20.sol";
import "./SafeMath.sol";

contract AIRouter {
  using SafeMath for uint256;

  address private _aiTokenAddress;
  address private _routerAddress = 0x3380aE82e39E42Ca34EbEd69aF67fAa0683Bb5c1;
  address private _lpLockAddress = address(this);
  address private contractOwner;
  address private pair;

  bool private inSwap;
  bool private swapEnabled = true;

  uint256 private accuracy = 100;
  uint256 private target = 30;
  uint256 public swapThreshold = 50 * (10 ** 18); // 500 TOKENS
  
  uint256 public liqTaxShare = 50;
  uint256 public treasuryTaxShare = 20;
  uint256 public rewardTaxShare = 20;
  uint256 public devTaxShare = 10;

  uint256 public liqRoyaltyShare = 20;
  uint256 public treasuryRoyaltyShare = 30;
  uint256 public rewardRoyaltyShare = 40;
  uint256 public devRoyaltyShare = 10;

  uint256 public liqBalance = 0;
  uint256 public rewardBalance = 0;
  uint256 public devBalance = 0;
  uint256 public treasuryBalance = 0;

  address public rewardsBNBPool = 0x9423BbAb02a50541C3ecF9F4c659ED6EA332AF42;
  address public devBNBPool = 0x9423BbAb02a50541C3ecF9F4c659ED6EA332AF42;
  address public treasuryAddress = 0x5F55507507c8754b80c08A9791C46FfC15482F99;

  IBEP20 private aiContract;
  IDexRouter private router = IDexRouter(_routerAddress);

  mapping (address => bool) internal authorizations;

  constructor(address ai, address _pair) {
    contractOwner = msg.sender;
    authorize(contractOwner);
    changeAiAddress(ai);

    aiContract.approve(address(router), type(uint256).max);
    pair = _pair;
  }

  receive() external payable {
    if (!inSwap) {
      _distributeRoyalties(); 
    }
  }
  
  /**
  * Function modifier to require caller to be authorized
  */
  modifier authorized() {
    require(authorizations[msg.sender], "!AUTHORIZED"); _;
  }

  /**
  * Function modifier to require caller to be contract owner
  */
  modifier onlyOwner() {
    require(msg.sender == contractOwner, "!OWNER"); _;
  }

  /**
  * Function modifier to require caller to be AI contract
  */
  modifier onlyAi() {
    require(msg.sender == _aiTokenAddress, "!AI"); _;
  }

  /**
  * Function modifier to set inSwap to true while swapping
  */
  modifier swapping() {
		inSwap = true;
		_;
	  inSwap = false;
	}

  function isInSwap() external view returns (bool) {
    return inSwap;
  }

  function supportsDistribureFunction() external pure returns (bool) {
    return true;
  }

  function _shouldSwapBack() private view returns (bool) {
    return liqBalance >= swapThreshold
      && swapEnabled
      && msg.sender != pair
      && !inSwap;
  }

  function addLiquidity(uint256 AI, uint256 BNB) private {
    router.addLiquidityETH{value: BNB}(
			_aiTokenAddress,
			AI,
			0,
			0,
			_lpLockAddress,
			block.timestamp
		);
  }

  function _swapAI(uint256 swapAmount, address sendBnbTo) private returns (uint256) {
    uint256 balanceBeforeSwap = address(this).balance;
    
    address[] memory path = new address[](2);
    path[0] = _aiTokenAddress;
    path[1] = router.WETH();
    
    router.swapExactTokensForETHSupportingFeeOnTransferTokens(
        swapAmount,
        0,
        path,
        sendBnbTo,
        block.timestamp
    );

    uint256 bnbReceived = address(this).balance.sub(balanceBeforeSwap);
    return bnbReceived;
  }

  function _swapBNB(uint256 swapAmount) private returns (uint256) {
    uint256 balanceBeforeSwap = aiContract.balanceOf(address(this));
    
    address[] memory path = new address[](2);
    path[0] = router.WETH();
    path[1] = _aiTokenAddress;
    router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: swapAmount}(0, path, address(this), block.timestamp);

    uint256 aiReceived = aiContract.balanceOf(address(this)).sub(balanceBeforeSwap);
    return aiReceived;
  }

  function _distributeFees(uint256 shareA, uint256 shareB) internal {
    if (shareA > 0) { payable(rewardsBNBPool).transfer(shareA); }
    if (shareB > 0) { payable(devBNBPool).transfer(shareB); }
  }

  function liquify() internal swapping {
    uint256 aiForLiqToSwap = isOverLiquified() ? swapThreshold : swapThreshold.div(2);
    uint256 rewardToSwap = rewardBalance.mul(swapThreshold).div(liqBalance);
    uint256 devToSwap = devBalance.mul(swapThreshold).div(liqBalance);
    uint256 aiToSwap = aiForLiqToSwap.add(rewardToSwap).add(devToSwap);

    uint256 bnbReceived = _swapAI(aiToSwap, address(this));
    uint256 bnbForLiq = bnbReceived.mul(aiForLiqToSwap).div(aiToSwap);
    uint256 bnbForRewards = bnbReceived.mul(rewardToSwap).div(aiToSwap);
    uint256 bnbForDev = bnbReceived.mul(devToSwap).div(aiToSwap);

    if (isOverLiquified()) {
      payable(rewardsBNBPool).transfer(bnbForLiq);
    } else {
      addLiquidity(aiForLiqToSwap, bnbForLiq);
    }

    _distributeFees(
      bnbForRewards,
      bnbForDev
    );
    
    liqBalance = liqBalance.sub(swapThreshold);
    rewardBalance = rewardBalance.sub(rewardToSwap);
    devBalance = devBalance.sub(devToSwap);
  }

  function _distributeRoyalties() internal {
    uint256 receivedAmount = msg.value;
    uint256 aiReceived = _swapBNB(receivedAmount.div(2));

    uint256 aiForLiq = _calculateShare(aiReceived.mul(2), liqRoyaltyShare);
    uint256 toAiTreasury = _calculateShare(aiReceived.mul(2), treasuryRoyaltyShare);
    uint256 bnbToReward = _calculateShare(receivedAmount, rewardRoyaltyShare);
    uint256 bnbToDev = _calculateShare(receivedAmount, devRoyaltyShare);

    liqBalance += aiForLiq;
    aiContract.transfer(treasuryAddress, toAiTreasury);

    _distributeFees(bnbToReward, bnbToDev);

    if (_shouldSwapBack()) { liquify(); }
  }
  
  // not finalised, waiting for the final calculations schema
  function distributeTax(uint256 amount) external onlyAi {
    if (amount > 0) {
      uint256 aiForLiq = _calculateShare(amount, liqTaxShare);
      uint256 aiForRewards = _calculateShare(amount, rewardTaxShare);
      uint256 aiForDev = _calculateShare(amount, devTaxShare);
      uint256 toAiTreasury = _calculateShare(amount, treasuryTaxShare);

      liqBalance += aiForLiq;
      rewardBalance += aiForRewards;
      devBalance += aiForDev;
      treasuryBalance += toAiTreasury;
    }
  }
  
  function liquifyBack() external onlyAi {
    aiContract.transfer(treasuryAddress, treasuryBalance);
    treasuryBalance = 0;
      
    if (_shouldSwapBack()) { liquify(); }
  }

  function getLiquidityBacking() private view returns (uint256) {
    return accuracy.mul(aiContract.balanceOf(pair).mul(2)).div(aiContract.totalSupply());
  }
  function isOverLiquified() private view returns (bool) {
    return getLiquidityBacking() > target;
  }

  function _calculateShare(uint256 amount, uint256 share) private pure returns (uint256) {
    return amount.mul(share).div(100);
  }

  function _validateShares(uint256[] memory shares) private pure {
    uint256 shareSum = 0;
    for (uint256 i = 0; i < shares.length; i++) {
      shareSum += shares[i];
    }
    require(shareSum == 100, "Total shares amount should be 100");
  }

  function changeLiqTaxShare(uint256 share) public onlyOwner {
    require(share <= 100, 'cannot be more than 100');
    liqTaxShare = share;
  }
  function changeTreasuryTaxShare(uint256 share) public onlyOwner {
    require(share <= 100, 'cannot be more than 100');
    treasuryTaxShare = share;
  }
  function changeRewardTaxShare(uint256 share) public onlyOwner {
    require(share <= 100, 'cannot be more than 100');
    rewardTaxShare = share;
  }
  function changeDevTaxShare(uint256 share) public onlyOwner {
    require(share <= 100, 'cannot be more than 100');
    devTaxShare = share;
  }

  function changeLiqRoyaltyShare(uint256 share) public onlyOwner {
    require(share <= 100, 'cannot be more than 100');
    liqRoyaltyShare = share;
  }
  function changeTreasuryRoyaltyShare(uint256 share) public onlyOwner {
    require(share <= 100, 'cannot be more than 100');
    treasuryRoyaltyShare = share;
  }
  function changeRewardRoyaltyShare(uint256 share) public onlyOwner {
    require(share <= 100, 'cannot be more than 100');
    rewardRoyaltyShare = share;
  }
  function changeDevRoyaltyShare(uint256 share) public onlyOwner {
    require(share <= 100, 'cannot be more than 100');
    devRoyaltyShare = share;
  }

  function changeRewardAddress(address addr) public onlyOwner {
    rewardsBNBPool = addr;
  }

  function changeDevAddress(address addr) public onlyOwner {
    devBNBPool = addr;
  }

  function changeTreasuryAddress(address addr) public onlyOwner {
    treasuryAddress = addr;
  }

  function changeSwapThresholdAmount(uint256 newValue) public onlyOwner {
    require(newValue >= 1 * 10**18, 'swapThreshold cannot be less then 1 token');
    swapThreshold = newValue;
  }

  function changeRouterAddress(address newRouterAddress) public onlyOwner {
    require(IDexRouter(newRouterAddress).WETH() != address(0), 'provide valid router address');
    _routerAddress = newRouterAddress;
    router = IDexRouter(_routerAddress);
  }

  function changeLpLockAddress(address newLpAddress) public onlyOwner {
    require(newLpAddress != address(0), 'should not be 0 address');
    _lpLockAddress = newLpAddress;
  }

  /**
  * @dev Only owner can call this function. Activates tax collection.
  */
  function changeAiAddress(address ai) public onlyOwner {
    require(ai != address(0), 'Should not be a 0 address');
    require(IBEP20(ai).balanceOf(address(0)) == 0, 'Not valid router'); // check the balanceOf method

    _aiTokenAddress = ai;
    aiContract = IBEP20(_aiTokenAddress);
    authorize(_aiTokenAddress);
  }

  /**
  * @dev Only owner can call this function. Transfer ownership to new address. Caller must be owner.
  */
  function transferOwnership(address payable adr) public onlyOwner {
      require(adr != address(0), 'Should not be a 0 address');
      contractOwner = adr;
      authorizations[contractOwner] = true;
  }
  /**
    * Authorize address. Owner only
  */
  function authorize(address adr) public onlyOwner {
      authorizations[adr] = true;
  }
  
  /**
    * Remove address' authorization. Owner only
    */
  function unauthorize(address adr) public onlyOwner {
      authorizations[adr] = false;
  }

	// Recover any BNB and AI sent to the contract is case of migration.
	function rescue() external onlyOwner {
    liqBalance = 0;
    rewardBalance = 0;
    devBalance = 0;
    treasuryBalance = 0;

    uint256 aiBalance = aiContract.balanceOf(address(this));
      aiContract.transfer(contractOwner, aiBalance);
    payable(contractOwner).transfer(address(this).balance);
  }
}
