// File contracts/Ownable.sol

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.18;

contract Ownable {

    address private _owner;

    event OwnershipTransferred(address indexed newOwner);

    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner,"Ownable: you are not the owner");
        _;
    }

    function changeOwner(address newOwner) public onlyOwner {
        _owner = newOwner;
        emit OwnershipTransferred(_owner);
    }
}


// File contracts/Constants.sol



pragma solidity 0.8.18;
contract Constants is Ownable {

    uint256 public _minRewardDuration;
    uint256 public _minStakingAmount;
    uint256 public _rewardMultiplierPerSecond;
    uint256 public _valorDuration;
    uint256 public _penaltyConstant;

    event MinRewardDurationAdjusted(uint256 minRewardDuration, uint256 newMinRewardDuration);
    event MinStakingAmountAdjusted(uint256 minStakingAmount, uint256 newMinStakingAmount);
    event RewardMultiplierAdjusted(uint256 rewardMultiplierPerSecond, uint256 newRewardMultiplierPerSecond);
    event ValorDurationAdjusted(uint256 valorDuration, uint256 newValorDuration);
    event PenaltyConstantAdjusted(uint256 penaltyConstant, uint256 newPenaltyConstant);

    // ONLY OWNER ADJUSTERS FOR CONSTANTS // 

    function adjustMinRewardDuration(uint256 newMinRewardDuration) public onlyOwner {
        emit MinRewardDurationAdjusted(_minRewardDuration, newMinRewardDuration);
        _minRewardDuration = newMinRewardDuration;
    }

    function adjustMinStakingAmount(uint256 newMinStakingAmount) public onlyOwner {
        emit MinStakingAmountAdjusted(_minStakingAmount, newMinStakingAmount);
        _minStakingAmount = newMinStakingAmount;
    }

    function adjustRewardMultiplier(uint256 newRewardMultiplierPerSecond) public onlyOwner {
        emit RewardMultiplierAdjusted(_rewardMultiplierPerSecond, newRewardMultiplierPerSecond);
        _rewardMultiplierPerSecond = newRewardMultiplierPerSecond;
    }

    function adjustValorDuration(uint256 newValorDuration) public onlyOwner {
        emit ValorDurationAdjusted(_valorDuration, newValorDuration);
        _valorDuration = newValorDuration;
    }

    function adjustPenaltyConstant(uint256 newPenaltyConstant) public onlyOwner {
        emit PenaltyConstantAdjusted(_penaltyConstant, newPenaltyConstant);
        _penaltyConstant = newPenaltyConstant;
    }

}


// File contracts/Storage.sol



pragma solidity 0.8.18;

contract Storage {

    uint256 public _rewardsDistributed;
    mapping(address => uint256) public _rewardsClaimed;

    mapping(address => uint[]) public _stakes;
    mapping(address => uint[]) public _stakeTimes;

    mapping(address => uint[]) public _withdrawals;
    mapping(address => uint[]) public _withdrawalTimes;

    event StakeEntryAdded(address indexed user, uint256 amount, uint256 time);
    event StakeEntryRemoved(address indexed user, uint256 amount, uint256 time);
    event WithdrawalEntryRemoved(address indexed user, uint256 amount, uint256 time);
    event WithdrawalEntryAdded(address indexed, uint256 amount, uint256 time);

    modifier onlyStaker() {
        require(_stakes[msg.sender].length != 0,"Storage: not a staker");
        _;
    }

    function stakes(address user) public view returns (uint[] memory, uint[] memory) {
        return (_stakes[user],_stakeTimes[user]);
    }

    function withdrawals(address user) public view returns (uint[] memory, uint[] memory) {
        return (_withdrawals[user],_withdrawalTimes[user]);
    }

    function _hasStake(address user) internal view returns(bool) {
        return _stakes[user].length != 0 ? true : false;
    }

    function _hasIndexedStake(address user, uint index) internal view returns(bool) {
        return _stakes[user][index] != 0 ? true : false;
    }

    function _hasIndexedWithdrawal(address user, uint index) internal view returns(bool) {
        return _withdrawals[user][index] != 0 ? true : false;
    }

    function _hasWithdrawal(address user) internal view returns(bool) {
        return _withdrawals[user].length != 0 ? true : false;
    }

    function _stakedAmount(address user, uint index) internal view returns(uint256) {
        return _stakes[user][index];
    }

    function _stakeTime(address user, uint index) internal view returns(uint256) {
        return _stakeTimes[user][index];
    }

    function _withdrawalAmount(address user, uint index) internal view returns(uint256) {
        return _withdrawals[user][index];
    }

    function _withdrawalTime(address user, uint index) internal view returns(uint256) {
        return _withdrawalTimes[user][index];
    }

    function _deleteStakeEntry(address user, uint index) internal {
        emit StakeEntryRemoved(user,_stakes[user][index],block.timestamp);
        if(_stakes[user].length != index + 1) {
            for (uint i = index; i < _stakes[user].length - 1; i++) {
                _stakes[user][i] = _stakes[user][i+1];
                _stakeTimes[user][i] = _stakeTimes[user][i+1];
            }
        } 
        _stakes[user].pop();
        _stakeTimes[user].pop();
    }

    function _addStakeEntry(address user, uint256 amount) internal {
        _stakes[user].push(amount);
        _stakeTimes[user].push(block.timestamp);
        emit StakeEntryAdded(user, amount, block.timestamp);
    }

    function _deleteWithdrawalEntry(address user, uint index) internal {
        emit WithdrawalEntryRemoved(user,_withdrawals[user][index],block.timestamp);
        if(_withdrawals[user].length != index + 1) {
            for (uint i = index; i < _withdrawals[user].length - 1; i++) {
                _withdrawals[user][i] = _withdrawals[user][i+1];
                _withdrawalTimes[user][i] = _withdrawalTimes[user][i+1];
            }
        } 
        _withdrawals[user].pop();
        _withdrawalTimes[user].pop();
    }

    function _addWithdrawalEntry(address user, uint256 amount) internal {
        _withdrawals[user].push(amount);
        _withdrawalTimes[user].push(block.timestamp);
        emit WithdrawalEntryAdded(user,amount,block.timestamp);
    }

    function _addRewardsDistributed(address user, uint256 amount) internal {
        _rewardsDistributed += amount;
        _rewardsClaimed[user] += amount;
    }
}


// File contracts/Calculations.sol



pragma solidity 0.8.18;
contract Calculations is Constants, Storage {

    function calculatePendingReward(address user, uint index) public view returns (uint256) {
        return _canRemoveStake(user, index) ? _calculateReward(_elapsedTime(user, index),_stakedAmount(user, index)) : 0;
    }

    function calculateReward(address user, uint index) public view returns (uint256) {
        return _calculateReward(_elapsedTime(user, index),_stakedAmount(user, index));
    }

    function _elapsedTime(address user, uint index) internal view returns (uint256) {
        return block.timestamp - _stakeTime(user, index);
    }

    function _canRemoveStake(address user, uint index) internal view returns (bool) {
        return _elapsedTime(user, index) > _minRewardDuration ? true : false;
    }

    function _calculateReward(uint256 elapsedTime, uint256 amount) internal view returns (uint) {
        uint amountUint = amount / 10**18;
        return amount + (amountUint * _rewardMultiplierPerSecond * elapsedTime);
    }

    function _calculatePenalty(uint256 amount) internal view returns (uint) {
        return amount * _penaltyConstant / 10**18;
    }

    function _elapsedWithdrawalTime(address user, uint index) internal view returns (uint256) {
        return block.timestamp - _withdrawalTime(user, index);
    }

    function _canWithdraw(address user, uint index) internal view returns (bool) {
        return _elapsedWithdrawalTime(user, index) >= _valorDuration ? true : false;
    }
   
}


// File contracts/OpenStake.sol



pragma solidity 0.8.18;
contract OpenStake is Calculations {

    bool private _isEmergency = false;

    event Stake(address indexed user, uint256 amount, uint256 time);
    event Unstake(address indexed user, uint256 amount, uint256 time);
    event UnstakeWithPenalty(address indexed user, uint256 amount, uint256 time);
    event Withdraw(address indexed user, uint256 amount, uint256 time);
    event Compound(address indexed user, uint256 amount, uint256 time);
    event EmergencySet(address indexed owner, uint256 time);
    event EmergencyUnstake(address indexed user, uint256 amount, uint256 time);
    event EmergencyWithdrawal(address indexed user, uint256 amount, uint256 time);

    constructor() {
        adjustMinRewardDuration(2592000);
        adjustMinStakingAmount(100000000000000000000);
        //0.37 in decimal for %37 APY is 370000000000000000
        //370000000000000000 / 31536000 is the number below 
        //for rewards in second in decimal
        adjustRewardMultiplier(11732623034);
        adjustValorDuration(86400);
        //0.94 in decimal for 6% penalty
        adjustPenaltyConstant(940000000000000000);
        setEmergency(true);
    }

    function depositToTreasury() public payable onlyOwner {}

    function withdrawFromTreasury(uint256 amount) public onlyOwner {
        address payable receiver = payable(msg.sender);
        receiver.transfer(amount);
    }

    function stake() public payable {
        require(!_isEmergency,"OpenStake: There is an emergency");
        require(msg.value >= _minStakingAmount,"OpenStake: stake amount too low");
        _addStakeEntry(msg.sender, msg.value);
        emit Stake(msg.sender, msg.value, block.timestamp);
    }

    function unstake(uint index) public {
        require(!_isEmergency,"OpenStake: There is an emergency");
        require(_hasIndexedStake(msg.sender, index),"OpenStake: You dont have a stake");
        require(_canRemoveStake(msg.sender, index),"OpenStake: You cant remove this stake now");
        uint calculatedReward = calculateReward(msg.sender, index);
        _addRewardsDistributed(msg.sender, calculatedReward - _stakedAmount(msg.sender, index));
        _addWithdrawalEntry(msg.sender, calculatedReward);
        emit Unstake(msg.sender,calculatedReward,block.timestamp);
        _deleteStakeEntry(msg.sender, index);
    }

    function unstakeWithPenalty(uint index) public {
        require(!_isEmergency,"OpenStake: There is an emergency");
        require(_hasIndexedStake(msg.sender, index),"OpenStake: You dont have a stake");
        require(!_canRemoveStake(msg.sender, index),"OpenStake: You can remove stake normally");
        uint penalty = _calculatePenalty(_stakedAmount(msg.sender, index));
        _addWithdrawalEntry(msg.sender, penalty);
        emit UnstakeWithPenalty(msg.sender, penalty, block.timestamp);
        _deleteStakeEntry(msg.sender, index);
    }

    function withdraw(uint index) public {
        require(!_isEmergency,"OpenStake: There is an emergency");
        require(_hasIndexedWithdrawal(msg.sender, index),"OpenStake: You dont have a withdrawal");
        require(_canWithdraw(msg.sender, index),"OpenStake: You cant withdraw now");
        address payable receiver = payable(msg.sender);
        receiver.transfer(_withdrawalAmount(msg.sender, index));
        emit Withdraw(msg.sender, _withdrawalAmount(msg.sender, index), block.timestamp);
        _deleteWithdrawalEntry(msg.sender, index);
    }

    function compound(uint index) public {
        require(!_isEmergency,"OpenStake: There is an emergency");
        require(_hasIndexedStake(msg.sender, index),"OpenStake: You dont have a stake");
        require(_canRemoveStake(msg.sender, index),"OpenStake: You cant compound stake now");
        uint reward = calculateReward(msg.sender, index);
        emit Compound(msg.sender, reward, block.timestamp);
        _deleteStakeEntry(msg.sender, index);
        _addStakeEntry(msg.sender, reward);
    }

    function setEmergency(bool status) public onlyOwner {
        _isEmergency = status;
        emit EmergencySet(msg.sender, block.timestamp);
    }

    function emergencyUnstake(uint index) public {
        require(_isEmergency,"OpenStake: there is no emergency");
        require(_hasIndexedStake(msg.sender, index),"OpenStake: You dont have a stake");
        address payable receiver = payable(msg.sender);
        uint stakedAmount = _stakedAmount(msg.sender, index);
        receiver.transfer(stakedAmount);
        emit EmergencyUnstake(msg.sender, stakedAmount, block.timestamp);
        _deleteStakeEntry(msg.sender, index);
    }

    function emergencyWithdrawal(uint index) public {
        require(_isEmergency,"OpenStake: there is no emergency");
        require(_hasIndexedWithdrawal(msg.sender, index),"OpenStake: You dont have a stake");
        address payable receiver = payable(msg.sender);
        uint withdrawalAmount = _withdrawalAmount(msg.sender, index);
        receiver.transfer(withdrawalAmount);
        emit EmergencyWithdrawal(msg.sender, withdrawalAmount, block.timestamp);
        _deleteWithdrawalEntry(msg.sender, index);
    }
}
