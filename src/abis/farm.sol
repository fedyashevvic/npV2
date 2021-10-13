contract AutoFarm is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 shares; // How many LP tokens the user has provided.
        uint256 rewardDebtBUST; // Reward debt. See explanation below.
        uint256 rewardDebtBNB;
        // We do some fancy math here. Basically, any point in time, the amount of BUST
        // entitled to a user but is pending to be distributed is:
        //
        //   amount = user.shares / sharesTotal * wantLockedTotal
        //   pending reward = (amount * pool.accBUSTPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws want tokens to a pool. Here's what happens:
        //   1. The pool's `accBUSTPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    struct PoolInfo {
        IERC20 want; // Address of the want token.
        uint256 allocPoint; // How many allocation points assigned to this pool. BUST to distribute per block.
        uint256 lastRewardBlock; // Last block number that BUST distribution occurs.
        uint256 accBUSTPerShare; // Accumulated BUST per share, times 1e12. See below.
        uint256 accBNBPerShare;// // Accumulated BNB per share, times 1e12. See below.
        address strat; // Strategy address that will auto compound want tokens
    }
    address public daoAddress;  
    address public stkAddress;
    address public rewardPool;
    uint public lastRPBlock ;
    
    uint public rPInterval;
    uint public defaultRewardValue=0;
    uint public defaultRewardValueBNB=0;
    address public BUST = 0xfD0507faC1152faF870C778ff6beb1cA3B9f7A1F;
    address public BNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public fundSourceBNB; //source of BUST tokens to pull from
    address public fundSourceBUST;////source of BNB tokens to pull from

    address public burnAddress = 0x000000000000000000000000000000000000dEaD;

    //initialize at zero and update later
    uint256 public BUSTPerBlock = 0; // BUST tokens distributed per block
    uint256 public BNBPerBlock= 0;//// BNB tokens distributed per block
    
    uint DENOMINATOR=10000;
    uint public dao=100;
    uint public poolRewardPercentage=9500;


    PoolInfo[] public poolInfo; // Info of each pool.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo; // Info of each user that stakes LP tokens.
    uint256 public totalAllocPoint = 0; // Total allocation points. Must be the sum of all allocation points in all pools.

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event PendingRewardsBUST(address indexed user,uint256 indexed pid,uint256 amount);
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    constructor( address _daoAddress, uint _daopercentage, address _rewardPool, uint256 _poolRewardPercentage, address _stkAddress,  uint _BNBPerBlock, uint _BUSTPerBlock, address _fundSourceBNB,  address _fundSourceBUST, uint _lastRPBlock, uint _rPInterval) public {       
    
          daoAddress= _daoAddress;
          dao = _daopercentage;
          rewardPool = _rewardPool;
          poolRewardPercentage=_poolRewardPercentage;
           stkAddress = _stkAddress;
             BNBPerBlock = _BNBPerBlock;
            defaultRewardValueBNB = _BNBPerBlock;
            BUSTPerBlock = _BUSTPerBlock;
            defaultRewardValue = _BUSTPerBlock;
            fundSourceBNB = _fundSourceBNB;
            fundSourceBUST = _fundSourceBUST;
            lastRPBlock = _lastRPBlock;
            rPInterval = _rPInterval;
            
        // bankroll , setBankRollPercentage, BNBPerBlock, BUSTPerBlock, daoAddress, setDAOPercentage, fundSourceBUST, fundSourceBNB, lastRPBlock, rewardPool, rewardpoolpercent, rPInterval, stkAddress
    }
    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do. (Only if want tokens are stored here.)

    function add(
        uint256 _allocPoint,
        IERC20 _want,
        bool _withUpdate,
        address _strat
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                want: _want,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accBUSTPerShare: 0,
                accBNBPerShare:0,
                strat: _strat
            })
        );
    }

    // Update the given pool's BUST allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }
    
    

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        pure
        returns (uint256)
    {
        return _to.sub(_from);
    }

    // View function to see pending BUST on frontend.
    function pendingBUST(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accBUSTPerShare = pool.accBUSTPerShare;
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        if (block.number > pool.lastRewardBlock && sharesTotal != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 BUSTReward =
                multiplier.mul(BUSTPerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            
            accBUSTPerShare = accBUSTPerShare.add(
                BUSTReward.mul(1e12).div(sharesTotal)
            );

            uint userReward=user.shares.mul(accBUSTPerShare).div(1e12).sub(user.rewardDebtBUST);

            uint reReward = userReward.mul(poolRewardPercentage).div(DENOMINATOR);
            uint daoReward=reReward.mul(dao).div(DENOMINATOR);
            reReward=reReward.sub(daoReward);
            return reReward;
        }
        return user.shares.mul(accBUSTPerShare).div(1e12).sub(user.rewardDebtBUST);
    }
        //  View function to see pending BUST on frontend.

        function pendingBNB(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accBNBPerShare = pool.accBNBPerShare;
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        if (block.number > pool.lastRewardBlock && sharesTotal != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 BNBReward =
                multiplier.mul(BNBPerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );

             accBNBPerShare = accBNBPerShare.add(
                BNBReward.mul(1e12).div(sharesTotal)
            );
            uint userReward=user.shares.mul(accBNBPerShare).div(1e12).sub(user.rewardDebtBNB);
                
           
            uint daoReward=userReward.mul(dao).div(DENOMINATOR);
            userReward=userReward.sub(daoReward); 
               
            return userReward;
        }
        return user.shares.mul(accBNBPerShare).div(1e12).sub(user.rewardDebtBNB);
    }

    // View function to see staked Want tokens on frontend.
    function stakedWantTokens(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        uint256 wantLockedTotal =
            IStrategy(poolInfo[_pid].strat).wantLockedTotal();
        if (sharesTotal == 0) {
            return 0;
        }
        return user.shares.mul(wantLockedTotal).div(sharesTotal);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        if (sharesTotal == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        if (multiplier <= 0) {
            return;
        }

        uint256 BUSTReward =
            multiplier.mul(BUSTPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );
            
         uint256 BNBReward=
             multiplier.mul(BNBPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );      

        getBUST(BUSTReward);
        getBNB(BNBReward);

        pool.accBUSTPerShare = pool.accBUSTPerShare.add(
            BUSTReward.mul(1e12).div(sharesTotal)
        );
        
        pool.accBNBPerShare = pool.accBNBPerShare.add(
            BNBReward.mul(1e12).div(sharesTotal)
        );
        pool.lastRewardBlock = block.number;

    }

    function _updateRewardPerBlock() internal{
         // auto calculate

        if(lastRPBlock.add(rPInterval) < block.number){
            
            uint rewardGenerated = IERC20(BUST).balanceOf(rewardPool);
            uint rewardGeneratedBNB = IERC20(BNB).balanceOf(rewardPool);
            
            uint increment = rewardGenerated.div(rPInterval);
            uint incrementBNB = rewardGeneratedBNB.div(rPInterval);
            
                if(increment > 0){
                BUSTPerBlock = defaultRewardValue.add(increment);
                IERC20(BUST).transferFrom(rewardPool, fundSourceBUST, rewardGenerated);
               
                }
                else{
                    BUSTPerBlock = defaultRewardValue;
                }
                
                if(incrementBNB > 0){
                BNBPerBlock = defaultRewardValueBNB.add(incrementBNB);
                IERC20(BNB).transferFrom(rewardPool, fundSourceBNB, rewardGeneratedBNB);
                }
                else{
                    BNBPerBlock = defaultRewardValueBNB;
                }
                
            lastRPBlock=block.number;
            
            
        }
        

    }

    // Want tokens moved from user -> BUSTFarm (BUST allocation) -> Strat (compounding)
    function deposit(uint256 _pid, uint256 _wantAmt) public nonReentrant {
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.shares > 0) {
            uint256 pendingBUSTD =
                user.shares.mul(pool.accBUSTPerShare).div(1e12).sub(
                    user.rewardDebtBUST
                );
                
                
            uint256 pendingBNBD =
                user.shares.mul(pool.accBNBPerShare).div(1e12).sub(
                    user.rewardDebtBNB
                );
                
            if (pendingBUSTD > 0) {
                uint poolRewardPart=pendingBUSTD.mul(poolRewardPercentage).div(DENOMINATOR);
                uint stakeRewardPart=pendingBUSTD.mul(DENOMINATOR.sub(poolRewardPercentage)).div(DENOMINATOR);
                uint daoReward=poolRewardPart.mul(dao).div(DENOMINATOR);
                poolRewardPart=poolRewardPart.sub(daoReward);
                safeBUSTTransfer(msg.sender,poolRewardPart);
                safeBUSTTransfer(daoAddress,daoReward);
                safeBUSTTransfer(stkAddress, stakeRewardPart);
                emit PendingRewardsBUST(msg.sender, _pid, pendingBUSTD);
            }
            
            if (pendingBNBD > 0) {
                uint daoReward=pendingBNBD.mul(dao).div(DENOMINATOR);
                pendingBNBD=pendingBNBD.sub(daoReward);
                safeBNBTransfer(msg.sender, pendingBNBD);
                safeBNBTransfer(daoAddress,daoReward);
                
            }
        }
        if (_wantAmt > 0) {
            pool.want.safeTransferFrom(
                address(msg.sender),
                address(this),
                _wantAmt
            );

            pool.want.safeIncreaseAllowance(pool.strat, _wantAmt);
            uint256 sharesAdded =
                IStrategy(poolInfo[_pid].strat).deposit(msg.sender, _wantAmt);
            user.shares = user.shares.add(sharesAdded);
        }
        user.rewardDebtBUST = user.shares.mul(pool.accBUSTPerShare).div(1e12);
        user.rewardDebtBNB = user.shares.mul(pool.accBNBPerShare).div(1e12);


        _updateRewardPerBlock();
        emit Deposit(msg.sender, _pid, _wantAmt);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _wantAmt) public nonReentrant {
        updatePool(_pid);

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 wantLockedTotal =
            IStrategy(poolInfo[_pid].strat).wantLockedTotal();
        uint256 sharesTotal = IStrategy(poolInfo[_pid].strat).sharesTotal();

        require(user.shares > 0, "user.shares is 0");
        require(sharesTotal > 0, "sharesTotal is 0");

        // Withdraw pending BUST
        uint256 pendingBUSTW =
            user.shares.mul(pool.accBUSTPerShare).div(1e12).sub(
                user.rewardDebtBUST
            );
            
        uint256 pendingBNBW =
            user.shares.mul(pool.accBNBPerShare).div(1e12).sub(
                user.rewardDebtBNB
            );
        if (pendingBUSTW > 0) {
                uint poolRewardPart=pendingBUSTW.mul(poolRewardPercentage).div(DENOMINATOR);
                uint stakeRewardPart=pendingBUSTW.mul(DENOMINATOR.sub(poolRewardPercentage)).div(DENOMINATOR);
                uint daoReward=poolRewardPart.mul(dao).div(DENOMINATOR);
                poolRewardPart=poolRewardPart.sub(daoReward);
                safeBUSTTransfer(msg.sender,poolRewardPart);
                safeBUSTTransfer(daoAddress,daoReward);
                safeBUSTTransfer(stkAddress, stakeRewardPart);
                emit PendingRewardsBUST(msg.sender, _pid, pendingBUSTW);
            }
            
        if (pendingBNBW > 0) {
                uint daoReward=pendingBNBW.mul(dao).div(DENOMINATOR);
                pendingBNBW=pendingBNBW.sub(daoReward);
                safeBNBTransfer(msg.sender, pendingBNBW);
                safeBNBTransfer(daoAddress,daoReward);
            }

        // Withdraw want tokens
        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);
        if (_wantAmt > amount) {
            _wantAmt = amount;
        }
        if (_wantAmt > 0) {
            uint256 sharesRemoved =
                IStrategy(poolInfo[_pid].strat).withdraw(msg.sender, _wantAmt);

            if (sharesRemoved > user.shares) {
                user.shares = 0;
            } else {
                user.shares = user.shares.sub(sharesRemoved);
            }

            uint256 wantBal = IERC20(pool.want).balanceOf(address(this));
            if (wantBal < _wantAmt) {
                _wantAmt = wantBal;
            }
            pool.want.safeTransfer(address(msg.sender), _wantAmt);
        }
        user.rewardDebtBUST = user.shares.mul(pool.accBUSTPerShare).div(1e12);
        user.rewardDebtBNB = user.shares.mul(pool.accBNBPerShare).div(1e12);
        _updateRewardPerBlock();
        emit Withdraw(msg.sender, _pid, _wantAmt);
    }

    function withdrawAll(uint256 _pid) public {
        withdraw(_pid, uint256(-1));
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 wantLockedTotal =
            IStrategy(poolInfo[_pid].strat).wantLockedTotal();
        uint256 sharesTotal = IStrategy(poolInfo[_pid].strat).sharesTotal();
        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);

        IStrategy(poolInfo[_pid].strat).withdraw(msg.sender, amount);

        pool.want.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
        user.shares = 0;
        user.rewardDebtBUST = 0;
        user.rewardDebtBNB = 0;
    }

    // Safe BUST transfer function, just in case if rounding error causes pool to not have enough
    function safeBUSTTransfer(address _to, uint256 _BUSTAmt) internal {
        uint256 BUSTBal = IERC20(BUST).balanceOf(address(this));
        if (_BUSTAmt > BUSTBal) {
            IERC20(BUST).transfer(_to, BUSTBal);
        } else {
            IERC20(BUST).transfer(_to, _BUSTAmt);
        }
    }
    
    // Safe BNB transfer function, just in case if rounding error causes pool to not have enough

    function safeBNBTransfer(address _to, uint256 _BNBAmt) internal {
        uint256 BNBBal = IERC20(BNB).balanceOf(address(this));
        if (_BNBAmt > BNBBal) {
            IERC20(BNB).transfer(_to, BNBBal);
        } else {
            IERC20(BNB).transfer(_to, _BNBAmt);
        }
    }

    //gets BUST for distribution from external address
    function getBUST(uint256 _BUSTAmt) internal {
        IERC20(BUST).transferFrom(fundSourceBUST, address(this), _BUSTAmt);
    }
    //gets BNB for distribution from external address
    function getBNB(uint256 _BNBAmt) internal {
        IERC20(BNB).transferFrom(fundSourceBNB, address(this), _BNBAmt);
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount)
        external
        onlyOwner
    {
        require(_token != BUST, "!safe");
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function setBUSTPerBlock(uint _BUSTPerBlock) external onlyOwner {
        BUSTPerBlock = _BUSTPerBlock;
        defaultRewardValue = _BUSTPerBlock;
    }
    
    function setBNBPerBlock(uint _BNBPerBlock) external onlyOwner {
        BNBPerBlock = _BNBPerBlock;
        defaultRewardValueBNB = _BNBPerBlock;
    }
    
    function setFundSourceBNB(address _fundSourceBNB) external onlyOwner {
        fundSourceBNB = _fundSourceBNB;
    }
    
    function setFundSourceBUST(address _fundSourceBUST) external onlyOwner {
        fundSourceBUST = _fundSourceBUST;
    }
    
    function setStkAddress(address _stkAddress) external onlyOwner {
        stkAddress = _stkAddress;
    }
    
    function setDaokAddress(address _daoAddress) external onlyOwner{
        daoAddress= _daoAddress;
    }
    
    function setRewardPool(address _rewardPool) external onlyOwner {
        rewardPool = _rewardPool;
    }

    function setLastRPBlock(uint _lastRPBlock) external onlyOwner {
        lastRPBlock = _lastRPBlock;
    }

    function setRPInterval(uint _rPInterval) external onlyOwner {
        rPInterval = _rPInterval;
    }

    
    function setDAOPercentage(uint _percentage)external onlyOwner{
        require(_percentage<DENOMINATOR, "should be less");
        dao=_percentage;
    }
    
    function setPoolRewardPercentage(uint256 _poolRewardPercentage) external onlyOwner{
        require(_poolRewardPercentage<=DENOMINATOR, "should be less than or equal too");
        poolRewardPercentage=_poolRewardPercentage;
    }
}