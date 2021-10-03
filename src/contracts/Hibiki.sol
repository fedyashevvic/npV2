// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./Auth.sol";
import "./IBEP20.sol";
import "./IDexRouter.sol";
import "./IDexFactory.sol";

contract Hibiki is IBEP20, Auth {

	string constant _name = "Hibiki.finance";
  string constant _symbol = "HIBIKI";
  uint8 constant _decimals = 18;

  uint256 _totalSupply = 10_000_000 * (10 ** _decimals);
  uint256 public _maxTxAmount = _totalSupply / 100;
	uint256 public _maxWalletAmount = _totalSupply / 100;

	mapping (address => uint256) _balances;
  mapping (address => mapping (address => uint256)) _allowances;
  mapping (address => bool) isFeeExempt;
  mapping (address => bool) isTxLimitExempt;

  // Fees. Some may be completely inactive at all times.
  uint256 liquidityFee = 30;
  uint256 burnFee = 0;
  uint256 stakingFee = 20;
  uint256 nftStakingFee = 0;
  uint256 feeDenominator = 1000;
  bool public feeOnNonTrade = false;

  uint256 public stakingPrizePool = 0;
  bool public stakingRewardsActive = false;
  address public stakingRewardsContract;
  uint256 public nftStakingPrizePool = 0;
  bool public nftStakingRewardsActive = false;
  address public nftStakingRewardsContract;

  address public autoLiquidityReceiver;

  IDexRouter public router;
  address pcs2BNBPair;
  address[] public pairs;

  bool public swapEnabled = true;
  uint256 public swapThreshold = 20000000000000000000; // < 500
  bool inSwap;
  modifier swapping() {
    inSwap = true;
    _;
    inSwap = false;
  }

    uint256 public launchedAt = 0;
    uint256 private antiSniperBlocks = 3;
    uint256 private antiSniperGasLimit = 30 gwei;
    bool private gasLimitActive = true;

    event AutoLiquifyEnabled(bool enabledOrNot);
    event AutoLiquify(uint256 amountBNB, uint256 autoBuybackAmount);
    event StakingRewards(bool activate);
    event NFTStakingRewards(bool active);

	constructor() Auth(msg.sender) {
		router = IDexRouter(0x3380aE82e39E42Ca34EbEd69aF67fAa0683Bb5c1);
    pcs2BNBPair = IDexFactory(router.factory()).createPair(router.WETH(), address(this));
    _allowances[address(this)][address(router)] = type(uint256).max;

    isFeeExempt[msg.sender] = true;
    isFeeExempt[address(this)] = true;

		autoLiquidityReceiver = msg.sender;
		pairs.push(pcs2BNBPair);
		_balances[msg.sender] = _totalSupply;

		emit Transfer(address(0), msg.sender, _totalSupply);
	}

	receive() external payable {}

  function totalSupply() external view override returns (uint256) { return _totalSupply; }
  function decimals() external pure override returns (uint8) { return _decimals; }
  function symbol() external pure override returns (string memory) { return _symbol; }
  function name() external pure override returns (string memory) { return _name; }
  function getOwner() external view override returns (address) { return owner; }
  function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
  function burn(uint256 burnQuantity) public override returns (bool) {
      _balances[msg.sender] = _balances[msg.sender] - burnQuantity;
      _totalSupply = _totalSupply - burnQuantity;
      emit Transfer(msg.sender, address(0), burnQuantity);
      return true;
  }
  function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }
  function approve(address spender, uint256 amount) public override returns (bool) {
      _allowances[msg.sender][spender] = amount;
      emit Approval(msg.sender, spender, amount);
      return true;
  }
  function approveMax(address spender) external returns (bool) { return approve(spender, type(uint256).max); }


  function transfer(address recipient, uint256 amount) external override returns (bool) { return _transferFrom(msg.sender, recipient, amount); }

	function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
    if (_allowances[sender][msg.sender] != type(uint256).max) {
      require(_allowances[sender][msg.sender] >= amount, "Insufficient Allowance");
      _allowances[sender][msg.sender] -= amount;
    }

    return _transferFrom(sender, recipient, amount);
  }

	function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
		require(amount > 0);

    if (inSwap) {
        return _basicTransfer(sender, recipient, amount);
    }

    // checks whether there is enouth tokens on balance to liquify the pair
    if (shouldSwapBack()) {
        liquify();
    }

    // activates the liquidity on DEX
    if (!launched() && recipient == pcs2BNBPair) {
        require(_balances[sender] > 0);
        require(sender == owner, "Only the owner can be the first to add liquidity.");
        launch();
    }

		require(amount <= _balances[sender], "Insufficient Balance");
    _balances[sender] -= amount;

    // checks whether it needs to take a fee and takes it before transferring to the 
    uint256 amountReceived = shouldTakeFee(sender, recipient) ? takeFee(sender, amount) : amount;
    _balances[recipient] += amountReceived;
    
    emit Transfer(sender, recipient, amountReceived);
    return true;
    }

	function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
		require(amount <= _balances[sender], "Insufficient Balance");
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
  }

	// Decides whether this trade should take a fee.
	// Trades with pairs are always taxed, unless sender or receiver is exempted.
	// Non trades, like wallet to wallet, are configured, untaxed by default.
	function shouldTakeFee(address sender, address recipient) internal view returns (bool) {
        if (isFeeExempt[sender] || isFeeExempt[recipient] || !launched()) {
			return false;
		}

        address[] memory liqPairs = pairs;
        for (uint256 i = 0; i < liqPairs.length; i++) {
            if (sender == liqPairs[i] || recipient == liqPairs[i]) {
				return true;
			}
        }

        return feeOnNonTrade;
    }

	function takeFee(address sender, uint256 amount) internal returns (uint256) {
		if (!launched()) { return amount; }

		uint256 liqFee = 0;
    
    // If there is a liquidity tax active for autoliq, the contract keeps it.
    if (liquidityFee > 0) {
      liqFee = amount * liquidityFee / feeDenominator;
      _balances[address(this)] += liqFee;
      emit Transfer(sender, address(this), liqFee);
    }

    return amount - liqFee;
  }

  function shouldSwapBack() internal view returns (bool) {
      return launched()
    && msg.sender != pcs2BNBPair
          && !inSwap
          && swapEnabled
          && _balances[address(this)] >= swapThreshold;
  }

	function setSwapEnabled(bool set) external authorized {
		swapEnabled = set;
		emit AutoLiquifyEnabled(set);
	}

	function liquify() internal swapping {
    // 500
    uint256 amountToLiquify = balanceOf(address(this)) / 2;  // 250
		// uint256 balanceBefore = address(this).balance; // X BNB == 0

    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = router.WETH();

    router.swapExactTokensForETHSupportingFeeOnTransferTokens(
        amountToLiquify,
        0,
        path,
        address(this),
        block.timestamp
    );

		emit AutoLiquify(balanceOf(address(this)), amountToLiquify);
  }

	function launched() internal view returns (bool) {
        return launchedAt != 0;
    }

    function launch() internal {
        launchedAt = block.number;
    }

    function setIsFeeExempt(address holder, bool exempt) external authorized {
        isFeeExempt[holder] = exempt;
    }

    function setFees(uint256 _liquidityFee, uint256 _burnFee, uint256 _stakingFee, uint256 _nftStakingFee, uint256 _feeDenominator) external authorized {
      liquidityFee = _liquidityFee;
      burnFee = _burnFee;
      stakingFee = _stakingFee;
      nftStakingFee = _nftStakingFee;
      feeDenominator = _feeDenominator;
      uint256 totalFee = _liquidityFee + _burnFee + _stakingFee + _nftStakingFee;
      require(totalFee < feeDenominator / 5, "Maximum allowed taxation on this contract is 20%.");
    }

    function setLiquidityReceiver(address _autoLiquidityReceiver) external authorized {
        autoLiquidityReceiver = _autoLiquidityReceiver;
    }

	// Recover any BNB sent to the contract by mistake.
	function rescue() external {
        payable(owner).transfer(address(this).balance);
    }

	function addPair(address pair) external authorized {
        pairs.push(pair);
    }
    
    function removeLastPair() external authorized {
        pairs.pop();
    }
}
