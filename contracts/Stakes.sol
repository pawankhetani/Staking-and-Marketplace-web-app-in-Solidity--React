// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface IERC20Staking {
    
    function balanceOf(address _owner) external view returns (uint256 balance);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function transfer(address _to, uint256 _value) external returns (bool success);
}

interface IERC20Reward {
    function transfer(address _to, uint256 _value) external returns (bool success);
    function balanceOf(address _owner) external view returns (uint256 balance);
}

contract Stakes {
    event Stake(address indexed _owner, uint256 _value, uint256 _time);
    event UnStake(address indexed _owner, uint256 _value, uint256 _time);

    uint256 constant private DECIMALS = 8;
    uint256 constant public STAKE_FEE = 5;
    uint256 constant public UNSTAKE_FEE = 15;
    uint256 constant public WITHDRAW_REWARD = 7;
    uint256 constant public SECONDS_IN_DAY = 86400;
    uint256 constant public WITHDRAW_PERCENTAGE = 10000;
    uint256 constant public STAKE_PERCENTAGE = 1000;
    uint256 constant public UNSTAKE_PERCENTAGE = 100;
    IERC20Staking immutable private stakingToken;
    IERC20Reward immutable private rewardToken;
    address immutable public owner;
    address immutable public wallet;
    uint256 constant public MIN_STAKE_VALUE = 200;
    struct Staking {
        bool isStaked;
        uint256 tokens;
        uint256 time;
        uint256 withdraws;
        uint256 earnings;
    }
    mapping (address => Staking) stakedBalances;

    constructor(address _stakingToken, address _rewardToken, address _wallet) {
        owner = msg.sender;
        stakingToken = IERC20Staking(_stakingToken);
        rewardToken = IERC20Reward(_rewardToken);
        wallet = _wallet;
    }

    function decimal() public pure returns(uint256) {
        return DECIMALS;
    }

    function stake(uint256 _value) public {
        //require(msg.sender == address(marketplace));
        //check if staked already
        require(stakedBalances[msg.sender].isStaked != true, "User can't restake untill unstake");
        //check for min stake && owner balance && marketplace allowance
        require(_value >= MIN_STAKE_VALUE*(10**decimal()), "Stake value less than min allowed");
        uint256 fee = (_value * STAKE_FEE) / STAKE_PERCENTAGE;
        stakingToken.transferFrom(msg.sender, address(this), _value);
        //transfer fee to wallet
        stakingToken.transfer(wallet, fee);
        stakedBalances[msg.sender].isStaked = true;
        stakedBalances[msg.sender].tokens = _value - fee;
        stakedBalances[msg.sender].time = block.timestamp;

        emit Stake(msg.sender, _value, block.timestamp);
    }

    function getStakedBalance(address _user) external view returns(uint256) {
        return stakedBalances[_user].tokens;
    }

    function unStake() public{
        //require(msg.sender == address(marketplace));
        require(stakedBalances[msg.sender].isStaked == true, "Tokens not staked!!");
        uint256 fees = (stakedBalances[msg.sender].tokens * UNSTAKE_FEE) / UNSTAKE_PERCENTAGE;
        //reentrancy protection
        uint256 remaining = stakedBalances[msg.sender].tokens - fees;
        delete stakedBalances[msg.sender];
        stakingToken.transfer(wallet, fees);
        stakingToken.transfer(msg.sender, remaining);

        emit UnStake(msg.sender, remaining, block.timestamp);
    }

    function calculateReward() public view returns (uint256,uint256,uint256){
        uint256 daysStaked = (block.timestamp - stakedBalances[msg.sender].time) / SECONDS_IN_DAY;
        uint256 withdraws = stakedBalances[msg.sender].withdraws;
        uint256 reward = (daysStaked - withdraws) * (stakedBalances[msg.sender].tokens * WITHDRAW_REWARD) / WITHDRAW_PERCENTAGE;
        return (reward,stakedBalances[msg.sender].earnings, stakedBalances[msg.sender].withdraws);
    }

    function withdrawReward() public {
        //require(msg.sender == address(marketplace));
        require(stakedBalances[msg.sender].isStaked == true, "Tokens not staked!!");
        uint256 daysStaked = (block.timestamp - stakedBalances[msg.sender].time) / SECONDS_IN_DAY;
        uint256 withdraws = stakedBalances[msg.sender].withdraws;
        //reward time completed && reward not already withdrawn
        require(daysStaked > 0 && withdraws < daysStaked, "Reward not available yet");
        stakedBalances[msg.sender].withdraws += 1;
        uint256 reward = (daysStaked - withdraws) * (stakedBalances[msg.sender].tokens * WITHDRAW_REWARD) / WITHDRAW_PERCENTAGE;
        stakedBalances[msg.sender].earnings += reward;
        rewardToken.transfer(msg.sender, reward);
    }
}