// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IDexRouter.sol";
import "./IBEP20.sol";
import "./SafeMath.sol";

contract AIRouter {
  using SafeMath for uint256;

  address private _aiTokenAddress;
  address private _routerAddress = 0x3380aE82e39E42Ca34EbEd69aF67fAa0683Bb5c1;
  address private _lpLockAddress = 0x51228d1FA3dCD52CCE7D08A1F3Db51c53F5Fb3fF;
  address private contractOwner;
  address private pair;

  bool private inSwap;
  bool private swapEnabled = true;

  uint256 private accuracy = 100;
  uint256 private target = 30;
  uint256 public swapThreshold = 100 * (10 ** 18); // 100 TOKENS
  
  uint256 private liqTaxShare = 50;
  uint256 private treasuryTaxShare = 20;
  uint256 private rewardTaxShare = 20;
  uint256 private devTaxShare = 10;

  uint256 private liqRoyaltyShare = 20;
  uint256 private treasuryRoyaltyShare = 30;
  uint256 private rewardRoyaltyShare = 40;
  uint256 private devRoyaltyShare = 10;

  uint256 public liqBalance = 0;
  uint256 public rewardBalance = 0;
  uint256 public devBalance = 0;

  address public rewardsBNBPool = 0x51228d1FA3dCD52CCE7D08A1F3Db51c53F5Fb3fF;
  address public devBNBPool = 0x51228d1FA3dCD52CCE7D08A1F3Db51c53F5Fb3fF;
  address public treasuryAddress = 0x51228d1FA3dCD52CCE7D08A1F3Db51c53F5Fb3fF;

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
    // if (!inSwap) {
    //   _distributeRoyalties();
    // }
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
  * Function modifier to set inSwap to true while swapping
  */
  // modifier swapping() {
	// 	aiContract.changeIsSwap(true);
	// 	_;
	// 	aiContract.changeIsSwap(false);
	// }

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

  function _swapAI(uint256 swapAmount) private returns (uint256) {
    uint256 balanceBeforeSwap = address(this).balance;
    
    address[] memory path = new address[](2);
    path[0] = _aiTokenAddress;
    path[1] = router.WETH();
    
    router.swapExactTokensForETHSupportingFeeOnTransferTokens(
        swapAmount,
        0,
        path,
        address(this),
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

  function liquify() internal {
    // uint256 aiForLiqToSwap = isOverLiquified() ? liqBalance : liqBalance.div(2);
    // uint256 aiToSwap = aiForLiqToSwap.add(rewardBalance).add(devBalance);

    // uint256 bnbReceived = _swapAI(aiToSwap);
    // uint256 bnbForLiq = bnbReceived.mul(aiForLiqToSwap).div(aiToSwap);
    // uint256 bnbForRewards = bnbReceived.mul(rewardTaxShare).div(aiToSwap);
    // uint256 bnbForDev = bnbReceived.mul(devTaxShare).div(aiToSwap);

    // if (isOverLiquified()) {
    //   payable(rewardsBNBPool).transfer(bnbForLiq);
    // } else {
    //   addLiquidity(aiForLiqToSwap, bnbForLiq);
    // }

    // _distributeFees(
    //   bnbForRewards,
    //   bnbForDev
    // );
    
    // liqBalance = aiContract.balanceOf(address(this));
    // rewardBalance = 0;
    // devBalance = 0;
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
  function distributeTax(uint256 amount) external swapping {
    // if (amount > 0) {
    //   uint256 aiForLiq = _calculateShare(amount, liqTaxShare);
    //   uint256 aiForRewards = _calculateShare(amount, rewardTaxShare);
    //   uint256 aiForDev = _calculateShare(amount, devTaxShare);
    //   uint256 toAiTreasury = _calculateShare(amount, treasuryTaxShare);

    //   liqBalance += aiForLiq;
    //   rewardBalance += aiForRewards;
    //   devBalance += aiForDev;

    //   aiContract.transfer(treasuryAddress, toAiTreasury);
      
    //   if (_shouldSwapBack()) { liquify(); }
    // }
    uint256 amountToLiquify = aiContract.balanceOf(address(this)) / 2; 

    address[] memory path = new address[](2);
    path[0] = address(aiContract);
    path[1] = router.WETH();

    router.swapExactTokensForETHSupportingFeeOnTransferTokens(
        amountToLiquify,
        0,
        path,
        address(this),
        block.timestamp
    );
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

  function changeTaxShares(uint256[] memory shares) public onlyOwner {
    require(shares.length == 4, 'Wrong number of shares provided');
    _validateShares(shares);

    liqTaxShare = shares[0];
    treasuryTaxShare = shares[1];
    rewardTaxShare = shares[2];
    devTaxShare = shares[3];
  }

  function changeRoyaltyShares(uint256[] memory shares) public onlyOwner {
    require(shares.length == 4, 'Wrong number of shares provided');
    _validateShares(shares);

    liqRoyaltyShare = shares[0];
    treasuryRoyaltyShare = shares[1];
    rewardRoyaltyShare = shares[2];
    devRoyaltyShare = shares[3];
  }

  function changeDistributionAddresses(address[] memory addreses) public onlyOwner {
    require(addreses.length == 3, 'Wrong number of wallets provided');

    rewardsBNBPool = addreses[0];
    devBNBPool = addreses[1];
    treasuryAddress = addreses[2];
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
}