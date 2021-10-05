// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./Auth.sol";
import "./IBEP20.sol";
import "./IDexRouter.sol";
import "./IDexFactory.sol";

contract AI is IBEP20, Auth {

	string constant _name = "AIv2";
  string constant _symbol = "AI";
  uint8 constant _decimals = 18;

  uint256 _totalSupply = 10_000_000 * (10 ** _decimals);
  uint256 public _maxTxAmount = _totalSupply / 100;
	uint256 public _maxWalletAmount = _totalSupply / 100;

	mapping (address => uint256) _balances;
  mapping (address => mapping (address => uint256)) _allowances;
  mapping (address => bool) isFeeExempt;
  mapping (address => address) private _taxAddresses;
  mapping (address => uint256) private _taxAmount;
  mapping (address => bool) private _isLaunched;

  // Fees. Some may be completely inactive at all times.
  uint256 liquidityFee = 50;
  uint256 feeDenominator = 1000;
  bool public feeOnNonTrade = false;

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

    event AutoLiquifyEnabled(bool enabledOrNot);

	constructor() Auth(msg.sender) {
		router = IDexRouter(0x3380aE82e39E42Ca34EbEd69aF67fAa0683Bb5c1);
    pcs2BNBPair = IDexFactory(router.factory()).createPair(router.WETH(), address(this));
    _allowances[address(this)][address(router)] = type(uint256).max;

    isFeeExempt[msg.sender] = true;
    isFeeExempt[address(this)] = true;

		autoLiquidityReceiver = msg.sender;
		pairs.push(pcs2BNBPair);
    _taxAddresses[pcs2BNBPair] = address(this);
    _taxAmount[pcs2BNBPair] = 50;
    _isLaunched[pcs2BNBPair] = false;
    
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

  function returnTradeAddress(address sender, address recipient) internal view returns (address) {
    address[] memory liqPairs = pairs;
    for (uint256 i = 0; i < liqPairs.length; i++) {
      if (sender == liqPairs[i] || recipient == liqPairs[i]) {
        return liqPairs[i];
      }
    }
    return address(0);
  }

	function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {

    // if inSwap _basicTransfer
    // launch
    // take fee
    // distribute tax, if needed liquify

		require(amount > 0);
    address tradeAddress = returnTradeAddress(sender, recipient);

    if (inSwap) {
      return _basicTransfer(sender, recipient, amount);
    }

    // activates the liquidity on DEX
    if (!_isLaunched[tradeAddress] && recipient == tradeAddress && tradeAddress != address(0)) {
        require(_balances[sender] > 0);
        require(sender == owner, "Only the owner can be the first to add liquidity.");
        _isLaunched[tradeAddress] = !_isLaunched[tradeAddress];
    }

    require(amount <= _balances[sender], "Insufficient Balance");
    _balances[sender] -= amount;

    // checks whether it needs to take a fee and takes it before transferring to the 
    uint256 amountReceived = shouldTakeFee(sender, recipient, tradeAddress) ? takeFee(sender, amount, tradeAddress) : amount;
    
    // checks whether there is enouth tokens on balance to liquify the pair
    if (shouldSwapBack(tradeAddress)) {
      liquify();
    }

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
	function shouldTakeFee(address sender, address recipient, address tradeAddress) internal view returns (bool) {
    if (isFeeExempt[sender] || isFeeExempt[recipient] || !_isLaunched[tradeAddress]) {
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

	function takeFee(address sender, uint256 amount, address tradeAddress) internal returns (uint256) {
		if (!_isLaunched[tradeAddress]) { return amount; }

		uint256 liqFee = 0;
    
    // If there is a liquidity tax active for autoliq, the contract keeps it.
    if (liquidityFee > 0) {
      liqFee = amount * _taxAmount[tradeAddress] / feeDenominator;
      _balances[_taxAddresses[tradeAddress]] += liqFee;
      emit Transfer(sender, address(this), liqFee);
    }

    return amount - liqFee;
  }

  function shouldSwapBack(address tradeAddress) internal view returns (bool) {
      return _isLaunched[tradeAddress]
    && msg.sender != tradeAddress
          && !inSwap
          && swapEnabled
          && _balances[address(this)] >= swapThreshold;
  }

	function setSwapEnabled(bool set) external authorized {
		swapEnabled = set;
		emit AutoLiquifyEnabled(set);
	}

	function liquify() internal swapping {
    uint256 amountToLiquify = balanceOf(address(this)); 

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
  }
  function setIsFeeExempt(address holder, bool exempt) external authorized {
      isFeeExempt[holder] = exempt;
  }

  function setFees(uint256 _liquidityFee, uint256 _feeDenominator) external authorized {
    liquidityFee = _liquidityFee;
    feeDenominator = _feeDenominator;
    require(_liquidityFee < feeDenominator / 5, "Maximum allowed taxation on this contract is 20%.");
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
