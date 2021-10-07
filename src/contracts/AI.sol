// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./Auth.sol";
import "./IBEP20.sol";
import "./IDexRouter.sol";
import "./IDexFactory.sol";


interface IAiRouter {
  function distributeTax(uint256 taxAmount) external;
  function isInSwap() external view returns (bool);
  function supportsDistribureFunction() external pure returns (bool);
  function authorize(address adr) external;
  function liquifyBack() external;
}

contract AI is IBEP20, Auth {

	string constant _name = "AIv2";
  string constant _symbol = "AI";
  uint8 constant _decimals = 18;

  // Constants
  uint256 public constant SECONDS_IN_A_DAY = 86400;
  uint256 public constant INITIAL_ALLOTMENT = 420000000000000000000;
  uint256 public constant emissionEnd = 1933606800;
  uint256 public constant aiSnapshot = 1632158133;
  uint256 public constant denominator = 100;

  // Public variables
  uint256 public emissionPerDay = 2300000000000000000;
  uint256 public MAX_EMISSION = 10000000000000000000;

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

  IDexRouter public router;
  address public ai2bnb;
  address[] public pairs;

  bool public swapEnabled = true;

  event TaxCollectionEnabled(bool enabledOrNot);

	constructor() Auth(msg.sender) {
		router = IDexRouter(0x3380aE82e39E42Ca34EbEd69aF67fAa0683Bb5c1);
    ai2bnb = IDexFactory(router.factory()).createPair(router.WETH(), address(this));
    _allowances[address(this)][address(router)] = type(uint256).max;

    isFeeExempt[msg.sender] = true;
    isFeeExempt[address(this)] = true;

		pairs.push(ai2bnb);
    _taxAddresses[ai2bnb] = address(this);
    _taxAmount[ai2bnb] = 50;
    _isLaunched[ai2bnb] = false;
    
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
	function _basicTransfer(address sender, address recipient, uint256 amount) internal  returns (bool) {
		require(amount <= _balances[sender], "Insufficient Balance");
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
  }
  function basicTransfer(address recipient, uint256 amount) external override returns (bool) { return _basicTransfer(msg.sender, recipient, amount); }

	function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {

    // if inSwap _basicTransfer
    // launch
    // take fee
    // distribute tax, if needed liquify

		require(amount > 0);
    address tradeAddress = returnTradeAddress(sender, recipient);
    bool isInSwap = IAiRouter(_taxAddresses[tradeAddress]).isInSwap();

    if (isInSwap) {
      return _basicTransfer(sender, recipient, amount);
    }

    // activates the liquidity on DEX
    if (!_isLaunched[tradeAddress] && recipient == tradeAddress && tradeAddress != address(0)) {
        require(_balances[sender] > 0);
        require(sender == owner, "Only the owner can be the first to add liquidity.");
        _isLaunched[tradeAddress] = !_isLaunched[tradeAddress];
        
        return _basicTransfer(sender, recipient, amount);
    }

    require(amount <= _balances[sender], "Insufficient Balance");
    _balances[sender] -= amount;

    // checks whether it needs to take a fee and takes it before transferring to the 
    uint256 amountReceived = shouldTakeFee(sender, recipient, tradeAddress) ? takeFee(sender, amount, tradeAddress) : amount;
    uint256 tax = amount - amountReceived;

    if (shouldSwapBack(tradeAddress) && !isInSwap && tax > 0) {
      IAiRouter(_taxAddresses[tradeAddress]).liquifyBack();
    }

    _balances[recipient] += amountReceived;
    emit Transfer(sender, recipient, amountReceived);
    return true;
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

	// Decides whether this trade should take a fee.
	// Trades with pairs are always taxed, unless sender or receiver is exempted.
	// Non trades, like wallet to wallet, are configured, untaxed by default.
	function shouldTakeFee(address sender, address recipient, address tradeAddress) internal view returns (bool) {
    if (isFeeExempt[sender] || isFeeExempt[recipient] || !_isLaunched[tradeAddress] || !swapEnabled) {
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
    if (_taxAmount[tradeAddress] > 0) {
      liqFee = amount * _taxAmount[tradeAddress] / feeDenominator;
      _balances[_taxAddresses[tradeAddress]] += liqFee;
      emit Transfer(sender, _taxAddresses[tradeAddress], liqFee);

      IAiRouter(_taxAddresses[tradeAddress]).distributeTax(liqFee);
    }

    return amount - liqFee;
  }

  function shouldSwapBack(address tradeAddress) internal view returns (bool) {
      return _isLaunched[tradeAddress]
          && msg.sender != tradeAddress
          && swapEnabled
          && _balances[_taxAddresses[tradeAddress]] > 0;
  }

	function setSwapEnabled(bool set) external authorized {
		swapEnabled = set;
		emit TaxCollectionEnabled(set);
	}

  function setIsFeeExempt(address holder, bool exempt) external authorized {
      isFeeExempt[holder] = exempt;
  }

	// Recover any BNB sent to the contract by mistake.
	function rescue() external {
        payable(owner).transfer(address(this).balance);
    }

	function addPair(address pair, address taxAddress, uint256 _newTaxAmount) external authorized {
      pairs.push(pair);
      _taxAddresses[pair] = taxAddress;
      _taxAmount[pair] = _newTaxAmount;
      isFeeExempt[pair] = true;
  }
    
  function removeLastPair() external authorized {
      pairs.pop();
  }

  /**
  * @dev Only owner can call this function. Tax amount, can be between 1 and 20.
  */
  function changeTaxAddressAndAmount(address tradeAddress, address taxAddress, uint256 _newTaxAmount) public onlyOwner {
    require(_newTaxAmount >= 0 && _newTaxAmount <= 200, 'Provide valid tax between 1 and 20');
    require(_taxAddresses[tradeAddress] != address(0), 'Trade address doesnt exist');
    _allowances[taxAddress][address(router)] = type(uint256).max;

    _taxAddresses[tradeAddress] = taxAddress;
    _taxAmount[tradeAddress] = _newTaxAmount;
    isFeeExempt[taxAddress] = true;
  }
}
