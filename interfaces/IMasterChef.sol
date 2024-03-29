// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface IMasterChef {
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    struct PoolInfo {
        address lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. SUSHI to distribute per block.
        uint256 lastRewardBlock;  // Last block number that SUSHI distribution occurs.
        uint256 accSushiPerShare; // Accumulated SUSHI per share, times 1e12. See below.
    }

    function pendingSushi(uint256 _pid, address _user)
        external
        view
        returns (uint256);

    function userInfo(uint256 _pid, address _user)
        external
        view
        returns (UserInfo memory);

    function owner() external view returns(address);

    function setZapLadex(address _zapLadex) external;

    function deposit(uint256 _pid, uint256 _amount) external payable;

    function depositTo(uint256 _pid, uint256 _amount, address _to) external payable;

    function depositSingleToken(uint256 _pid, uint256 _amount, address _depositToken) external payable;

    function depositSingleTokenTo(uint256 _pid, uint256 _amount, address _depositToken, address _to) external payable;

    function claim(uint256 _pid) external;

    function withdraw(uint256 _pid, uint256 _amount) external payable;

    function withdrawSingleToken(uint256 _pid, uint256 _amount, address _depositToken) external payable;

    function setSushiPerBlock(uint256 _sushiPerBlock) external;

    function setFee(uint256 _fee) external;

    function setWETH(address _WETH) external;

    function setRouter(address _router) external;

    function wrapFees() external;

    function sushiPerBlock() external view returns (uint256);

    function zapLadex() external view returns (address);
    
    function fee() external view returns (uint256);
    
    function WETH() external view returns (address);
    
    function router() external view returns (address);

    function add(
        uint256 _allocPoint,
        address _lpToken,
        address _rewardToken,
        uint256 _rewardPerBlock,
        bool _withUpdate
    ) external;

    function initialize(
        address _sushi,
        address _devaddr,
        uint256 _sushiPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    )  external;

    function poolInfo(uint256 pid) external view returns (IMasterChef.PoolInfo memory);
    function totalAllocPoint() external view returns (uint256);
}
