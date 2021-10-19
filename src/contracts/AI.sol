// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./Auth.sol";
import "./IBEP20.sol";
import "./SafeMath.sol";
import "./IERC721Enumerable.sol";

interface INeuralPepe is IERC721Enumerable {
    function isMintedBeforeReveal(uint256 index) external view returns (bool);
}

interface IAiRouter {
  function distributeTax(uint256 taxAmount) external;
  function isInSwap() external view returns (bool);
  function supportsDistribureFunction() external pure returns (bool);
  function authorize(address adr) external;
  function liquifyBack() external;
}

contract AI is IBEP20, Auth {
  using SafeMath for uint256;

	string constant _name = "AIv2";
  string constant _symbol = "AI";
  uint8 constant _decimals = 18;

  // Constants
  uint256 public constant SECONDS_IN_A_DAY = 86400;
  uint256 public constant emissionEnd = 1933606800;
  uint256 public constant aiSnapshot = 1632158133;

  // Public variables
  uint256 public emissionPerDay = 2300000000000000000;
  uint256 private MAX_EMISSION_PER_DAY = 10000000000000000000;
  uint256 private _totalSupply;

	mapping (address => uint256) _balances;
  mapping (address => mapping (address => uint256)) _allowances;
  mapping (address => bool) isFeeExempt;
  mapping(uint256 => uint256) private _lastClaim;
  mapping (address => address) private _taxAddresses;
  mapping (address => uint256) private _taxAmount;
  mapping (address => bool) private _isLaunched;

  // Fees. Some may be completely inactive at all times.
  uint256 feeDenominator = 1000;

  address private _pepeAddress = 0xa16b13cdFee9a134d17957Bef09dC3B5a4FddC1B;
  address[] private pairs; 
  INeuralPepe private PEPE = INeuralPepe(_pepeAddress);

  bool public swapEnabled = true;

  event TaxCollectionEnabled(bool enabledOrNot);

	constructor(uint256 valueToMint) Auth(msg.sender) {
    isFeeExempt[msg.sender] = true;
    isFeeExempt[address(this)] = true;
    
		_mint(owner, valueToMint);
	}

	receive() external payable {}

  function totalSupply() external view override returns (uint256) { return _totalSupply; }
  function decimals() external pure override returns (uint8) { return _decimals; }
  function symbol() external pure override returns (string memory) { return _symbol; }
  function name() external pure override returns (string memory) { return _name; }
  function getOwner() external view override returns (address) { return owner; }
  function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
  function burn(uint256 burnQuantity) public override returns (bool) {
      _balances[msg.sender] = _balances[msg.sender].sub(burnQuantity);
      _totalSupply = _totalSupply.sub(burnQuantity);
      emit Transfer(msg.sender, address(0), burnQuantity);
      return true;
  }
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
  function _mint(address account, uint256 amount) internal virtual {
    require(account != address(0), "ERC20: mint to the zero address");

    _beforeTokenTransfer(address(0), account, amount);

    _totalSupply = _totalSupply.add(amount);
    _balances[account] = _balances[account].add(amount);
    emit Transfer(address(0), account, amount);
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
  // function basicTransfer(address recipient, uint256 amount) external override returns (bool) { return _basicTransfer(msg.sender, recipient, amount); }

	function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
		require(amount > 0);
    address tradeAddress = returnTradeAddress(sender, recipient);
    bool isInSwap = tradeAddress != address(0) ? IAiRouter(_taxAddresses[tradeAddress]).isInSwap() : true;

    if (isInSwap || tradeAddress == address(0)) {
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
    uint256 tax = amount.sub(amountReceived);

    if (shouldSwapBack(tradeAddress) && !isInSwap && tax > 0) {
      try IAiRouter(_taxAddresses[tradeAddress]).liquifyBack() {} catch {}
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

    return false;
    }

	function takeFee(address sender, uint256 amount, address tradeAddress) internal returns (uint256) {
		if (!_isLaunched[tradeAddress]) { return amount; }

		uint256 liqFee = 0;
    
    // If there is a liquidity tax active for autoliq, the contract keeps it.
    if (_taxAmount[tradeAddress] > 0) {
      liqFee = amount.mul(_taxAmount[tradeAddress]).div(feeDenominator);
      _balances[_taxAddresses[tradeAddress]] += liqFee;
      emit Transfer(sender, _taxAddresses[tradeAddress], liqFee);

      try IAiRouter(_taxAddresses[tradeAddress]).distributeTax(liqFee) {} catch {}
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
    * @dev Only owner can call this function. Remove taxable address.
  */
  function removePair(address pairAddressToRemove) public onlyOwner {
    require(_isTradeAddressExists(pairAddressToRemove), 'The address you try to remove doesnt exist');
    uint addressIndex = _getAddressIndex(pairAddressToRemove).sub(1);

    for (uint i = addressIndex; i < pairs.length - 1; i++) {
      pairs[i] = pairs[pairs.length - 1];
    }
    pairs.pop();
  }

    /**
    * @dev Internal functions.
    */
  function _isTradeAddressExists(address tradeAddress) private view returns (bool) {
    if (pairs.length == 0) { return false; }
    for(uint i = 0; i < pairs.length; i++) {
      if (pairs[i] == tradeAddress) {
        return true;
      }
    }
    return false;
  }

  function _getAddressIndex(address tradeAddress) private view returns (uint) {
    for(uint i = 0; i < pairs.length; i++) {
      if (pairs[i] == tradeAddress) {
        return i.add(1);
      }
    }
    return 0;
  }


  /**
  * @dev When accumulated AIs have last been claimed for a Neural Pepe index
  */
  function lastClaim(uint256 tokenIndex) public view returns (uint256) {
      require(PEPE.ownerOf(tokenIndex) != address(0), "Owner cannot be 0 address");
      
      uint256 lastClaimed = uint256(_lastClaim[tokenIndex]) != 0 ? uint256(_lastClaim[tokenIndex]) : aiSnapshot;
      return lastClaimed;
  }

  /**
    * @dev Accumulated AI tokens for a Neural Pepe token index.
    */
  function accumulated(uint256 tokenIndex) public view returns (uint256) {
      require(PEPE.ownerOf(tokenIndex) != address(0), "Owner cannot be 0 address");
      require(tokenIndex < PEPE.totalSupply(), "AI at index has not been minted yet");

      uint256 lastClaimed = lastClaim(tokenIndex);

      // Sanity check if last claim was on or after emission end
      if (lastClaimed >= emissionEnd) return 0;

      uint256 accumulationPeriod = block.timestamp < emissionEnd ? block.timestamp : emissionEnd; // Getting the min value of both
      uint256 totalAccumulated = accumulationPeriod.sub(lastClaimed).mul(emissionPerDay).div(SECONDS_IN_A_DAY);

      return totalAccumulated;
  }

  /**
    * @dev Claim mints AIs and supports multiple Neural Pepe token indices at once.
    */
  function claim(uint256[] memory tokenIndices) public returns (uint256) {
      uint256 totalClaimQty = 0;
      for (uint i = 0; i < tokenIndices.length; i++) {
          // Sanity check for non-minted index
          require(tokenIndices[i] < PEPE.totalSupply(), "AI at index has not been minted yet");
          // Duplicate token index check
          for (uint j = i + 1; j < tokenIndices.length; j++) {
              require(tokenIndices[i] != tokenIndices[j], "Duplicate token index");
          }

          uint tokenIndex = tokenIndices[i];
          require(PEPE.ownerOf(tokenIndex) == msg.sender, "Sender is not the owner");

          uint256 claimQty = accumulated(tokenIndex);
          if (claimQty != 0) {
              totalClaimQty = totalClaimQty.add(claimQty);
              _lastClaim[tokenIndex] = block.timestamp;
          }
      }

      require(totalClaimQty != 0, "No accumulated AI");
      _mint(msg.sender, totalClaimQty);
      return totalClaimQty;
  }

  /**
    * @dev Only owner can call this function. Change AI emission per day.
    */
  function changeEmissionPerDay(uint256 _newEmissionPerDay) public onlyOwner {
    require(_newEmissionPerDay >= 0 || _newEmissionPerDay <= MAX_EMISSION_PER_DAY, 'invalid emission per day');
    emissionPerDay = _newEmissionPerDay;
  }


  /**
  * @dev Only owner can call this function. Tax amount, can be between 1 and 20.
  */
  function changeTaxAddressAndAmount(address tradeAddress, address taxAddress, uint256 _newTaxAmount) public onlyOwner {
    require(_newTaxAmount >= 0 && _newTaxAmount <= 200, 'Provide valid tax between 1 and 20');
    require(_taxAddresses[tradeAddress] != address(0), 'Trade address doesnt exist');

    _taxAddresses[tradeAddress] = taxAddress;
    _taxAmount[tradeAddress] = _newTaxAmount;
    isFeeExempt[taxAddress] = true;
  }

}