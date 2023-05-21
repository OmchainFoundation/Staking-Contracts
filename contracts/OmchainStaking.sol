// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

contract OmchainStakingV2 is ReentrancyGuard {

  /* ========== STATE VARIABLES AND STRUCTS ========== */

  address public owner;

  uint256 public periodFinish;
  uint256 public rewardRate;
  uint256 public rewardsDuration;
  uint256 public lastUpdateTime;
  uint256 public rewardPerTokenStored;

  uint256 private _totalSupply;
  mapping(address => uint256) private _balancesWithConstant;

  bool public isPaused;

  struct StakeTerm {
    uint256 minAmount;
    uint256 duration;
    uint256 withdrawalDelay;
    uint256 stakeConstant;
  }

  struct StakeEntry {
    uint256 amount;
    uint256 start;
    uint256 end;
    uint256 withdrawalDeadline;
    uint256 stakeConstant;
    uint256 reward;
    uint256 rewardPerTokenPaid;
  }

  struct WithdrawalEntry {
    uint256 amount;
    uint256 deadline;
  }

  mapping(uint256 => StakeTerm) public stakeTerms;
  mapping(address => StakeEntry[]) public stakeEntries;
  mapping(address => WithdrawalEntry[]) public withdrawalEntries;

  /* ========== EVENTS ========== */

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event RewardUpdated(address indexed user, uint256 stakeEntryIndex);
  event DepositToTreasury(uint256 blockNumber, uint256 amount);
  event WithdrawFromTreasury(uint256 blockNumber, uint256 amount);
  event Paused(address account, uint256 blockNumber);
  event Unpaused(address account, uint256 blockNumber);
  event StakeTermAdded(uint256 termId, uint256 minAmount, uint256 duration, uint256 withdrawalDelay, uint256 stakeConstant);
  event Staked(address indexed user, uint256 amount, uint256 stakeTerm);
  event Exit(address indexed user, uint256 stakeEntryIndex);
  event Claimed(address indexed user, uint256 withdrawalId, uint256 amount);
  event RewardAmountAdjusted(uint256 rewardAmount);
  event RewardDurationSet(uint256 rewardsDuration);
  event Withdraw(address indexed user, uint256 stakeEntryIndex, uint256 withdrawalEntryIndex);
  event RewardGranted(address indexed user, uint256 amount);

  /* ========== MODIFIERS ========== */

  modifier onlyOwner() {
    require(msg.sender == owner, "Only owner can call this function.");
    _;
  }

  modifier updateReward(address account, uint256 stakeEntryIndex) {
    rewardPerTokenStored = rewardPerToken();
    lastUpdateTime = lastTimeRewardApplicable();
    if (account != address(0)) {
      stakeEntries[account][stakeEntryIndex].reward = earned(account, stakeEntryIndex);
      stakeEntries[account][stakeEntryIndex].rewardPerTokenPaid = rewardPerTokenStored;
    }
    emit RewardUpdated(account, stakeEntryIndex);
    _;
  }

  modifier onlyValidTerm(uint256 termId) {
    require(stakeTerms[termId].stakeConstant > 0, "Invalid term id.");
    require(msg.value >= stakeTerms[termId].minAmount, "Insufficient amount.");
    _;
  }

  modifier notPaused() {
    require(!isPaused, "Contract is paused.");
    _;
  }

  /* ========== CONSTRUCTOR ========== */
  constructor() {
    owner = msg.sender;
    addStakeTerm(1, 100 ether, 30 days, 1 days, 6);
    addStakeTerm(2, 100 ether, 60 days, 2 days, 8);
    addStakeTerm(3, 100 ether, 180 days, 3 days, 13);
    addStakeTerm(4, 100 ether, 360 days, 7 days, 25);
    addStakeTerm(5, 100 ether, 720 days, 14 days, 40);
  }

  /* ========== VIEWS ========== */

  function earned(address account, uint256 stakeEntryIndex) public view returns (uint256) {
    return stakeEntries[account][stakeEntryIndex].amount * 
              stakeEntries[account][stakeEntryIndex].stakeConstant * 
              (rewardPerToken() - stakeEntries[account][stakeEntryIndex].rewardPerTokenPaid) / 1e18 + stakeEntries[account][stakeEntryIndex].reward;
  }

  function lastTimeRewardApplicable() public view returns (uint256) {
    return block.timestamp < periodFinish ? block.timestamp : periodFinish;
  }

  function rewardPerToken() public view returns (uint256) {
    if (_totalSupply == 0) {
        return rewardPerTokenStored;
    }
    return
        rewardPerTokenStored + 
            ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18 / _totalSupply);
  }

  function getRewardForDuration() external view returns (uint256) {
    return rewardRate * rewardsDuration;
  }

  function stakes(address account) public view returns (StakeEntry[] memory) {
      return stakeEntries[account];
  }

  function withdrawals(address account) public view returns (WithdrawalEntry[] memory) {
      return withdrawalEntries[account];
  }

  /* ========== TREASURY FUNCTIONS ========== */
  function deposit() public payable {
    emit DepositToTreasury(block.number, msg.value);
  }

  function withdrawTreasury(uint256 amount) public nonReentrant onlyOwner {
    payable(msg.sender).transfer(amount);
    emit WithdrawFromTreasury(block.number, amount);
  }

  /* ========== MUTATIVE FUNCTIONS ========== */

  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    owner = newOwner;
    emit OwnershipTransferred(msg.sender, newOwner);
  }

  function pause() public onlyOwner {
    isPaused = true;
    emit Paused(msg.sender, block.number);
  }

  function unpause() public onlyOwner {
    isPaused = false;
    emit Unpaused(msg.sender, block.number);
  }

  function addStakeTerm(
    uint256 termId,
    uint256 minAmount,
    uint256 duration,
    uint256 withdrawalDelay,
    uint256 stakeConstant
  ) public onlyOwner {
    stakeTerms[termId] = StakeTerm(minAmount, duration, withdrawalDelay, stakeConstant);
    emit StakeTermAdded(termId, minAmount, duration, withdrawalDelay, stakeConstant);
  }

  function stake(
    uint256 amount, 
    uint256 stakeTerm
  ) external payable nonReentrant notPaused onlyValidTerm(stakeTerm) {
      require(msg.value == amount, "StakingRewards: stake amount does not match msg.value");
      uint256 stakeEnd = stakeTerms[stakeTerm].duration + block.timestamp;
      uint256 stakeConstant = stakeTerms[stakeTerm].stakeConstant;
      rewardPerTokenStored = rewardPerToken();
      lastUpdateTime = lastTimeRewardApplicable();
      stakeEntries[msg.sender].push(
        StakeEntry(
          amount, 
          block.timestamp, 
          stakeEnd, 
          stakeEnd + stakeTerms[stakeTerm].withdrawalDelay,
          stakeConstant, 
          0, 
          rewardPerTokenStored
        )
      );

      _totalSupply += amount * stakeConstant;
      _balancesWithConstant[msg.sender] += amount * stakeConstant;
      emit Staked(msg.sender, amount, stakeTerm);
  }

  function exit(uint256 stakeEntryIndex) external nonReentrant notPaused() {
    withdraw(stakeEntryIndex);
    getReward(stakeEntryIndex);

    stakeEntries[msg.sender][stakeEntryIndex] = stakeEntries[msg.sender][stakeEntries[msg.sender].length - 1];
    stakeEntries[msg.sender].pop();

    emit Exit(msg.sender, stakeEntryIndex);
  }

  function claim(uint256 withdrawalId) external nonReentrant notPaused() {
    require(withdrawalEntries[msg.sender][withdrawalId].deadline <= block.timestamp, "Withdrawal time has not come yet.");
    require(withdrawalEntries[msg.sender][withdrawalId].amount > 0, "No such withdrawal");
    uint256 amount = withdrawalEntries[msg.sender][withdrawalId].amount;

    withdrawalEntries[msg.sender][withdrawalId] = withdrawalEntries[msg.sender][withdrawalEntries[msg.sender].length - 1];
    withdrawalEntries[msg.sender].pop();

    payable(msg.sender).transfer(amount);
    emit Claimed(msg.sender, withdrawalId, amount);
  }

  function notifyRewardAmount(uint256 reward) external onlyOwner updateReward(address(0), 0) {
    require(reward > 0, "Reward must be greater than zero");
    if (block.timestamp >= periodFinish) {
        rewardRate = reward / rewardsDuration;
    } else {
        uint256 remaining = periodFinish - block.timestamp;
        uint256 leftover = remaining * rewardRate;
        rewardRate = (reward + leftover) / rewardsDuration;
    }
    lastUpdateTime = block.timestamp;
    periodFinish = block.timestamp + rewardsDuration;

    emit RewardAmountAdjusted(reward);
  }

  function setRewardsDuration(uint256 newRewardsDuration) onlyOwner external {
    require(
        block.timestamp > periodFinish,
        "StakingRewards: rewards duration can only be updated after the period ends"
    );
    rewardsDuration = newRewardsDuration;
    emit RewardDurationSet(rewardsDuration);
  }

  /* ========== INTERNAL FUNCTIONS ========== */
  
  function withdraw(uint256 stakeEntryIndex) internal updateReward(msg.sender, stakeEntryIndex) {
    StakeEntry memory stakeEntry = stakeEntries[msg.sender][stakeEntryIndex];
    require(stakeEntry.end < block.timestamp, "Stake is not yet finished.");
    require(stakeEntry.amount > 0, "Stake amount is zero.");
    uint256 amount = stakeEntry.amount;
    uint256 stakeConstant = stakeEntry.stakeConstant;
    _totalSupply -= amount * stakeConstant;
    _balancesWithConstant[msg.sender] -= amount * stakeConstant;
    withdrawalEntries[msg.sender].push(
      WithdrawalEntry(amount, stakeEntries[msg.sender][stakeEntryIndex].withdrawalDeadline)
    );
    emit Withdraw(msg.sender, stakeEntryIndex, withdrawalEntries[msg.sender].length - 1);
  }

  function getReward(uint256 stakeEntryIndex) internal updateReward(msg.sender, stakeEntryIndex) {
    require(stakeEntries[msg.sender][stakeEntryIndex].end < block.timestamp, "Stake is not yet finished.");
    uint256 reward = stakeEntries[msg.sender][stakeEntryIndex].reward;
    if (reward > 0) {
      stakeEntries[msg.sender][stakeEntryIndex].reward = 0;
      withdrawalEntries[msg.sender][withdrawalEntries[msg.sender].length - 1].amount += reward;
    }
    emit RewardGranted(msg.sender, reward);
  }

}
