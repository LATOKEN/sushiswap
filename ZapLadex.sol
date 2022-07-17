// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "./openzeppelin/contracts/access/UpgradableOwnable.sol";
import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IMasterChef.sol";
import "./libraries/Babylonian.sol";
import "./libraries/SafeMath.sol";
import "./utils/Proxy.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}

contract ZapLadex is Storage, UpgradableOwnable {
    using SafeMath for uint256;

    IWETH public WETH;
    uint256 public constant minimumAmount = 1000;

    IUniswapV2Router public router;

    IMasterChef public masterChef;

    function initialize(address wethAddress, address routerAddress, address masterChefAddress) public {
        WETH = IWETH(wethAddress);
        
        router = IUniswapV2Router(routerAddress);
        masterChef = IMasterChef(masterChefAddress);

        ownableInit(msg.sender);
    }

    receive() external payable {
        assert(msg.sender == address(WETH));
    }

    function setRouter(address routerAddress) external onlyOwner {
        router = IUniswapV2Router(routerAddress);
    }

    function setMasterChef(address masterChefAddress) external onlyOwner {
        masterChef = IMasterChef(masterChefAddress);
    }

    function deposit(uint256 pid, uint256 amount, IERC20 wantToken) external payable {
        IMasterChef.PoolInfo poolInfo = masterChef.poolInfo(pid);

        if (address(wantToken) == address(WETH)) {
            WETH.deposit{value: amount}();
        } else {
            wantToken.transferFrom(
                msg.sender,
                address(this),
                amount
            );
        }

        uint256 beforeWantBalance = wantToken.balanceOf(address(this)).sub(amount);
        uint256 beforeRewardBalance = poolInfo.rewardToken.balanceOf(address(this));

        _handleZap(pid, wantToken, IUniswapV2Pair(poolInfo.lpToken), amount, true);

        _returnAsset(wantToken, wantToken.balanceOf(address(this)).sub(beforeWantBalance), msg.sender);
        if (address(poolInfo.rewardToken) != address(wantToken)) {
            _returnAsset(poolInfo.rewardToken, poolInfo.rewardToken.balanceOf(address(this)).sub(beforeRewardBalance), msg.sender);
        }
    }

    function withdraw(uint256 pid, uint256 amount, IERC20 wantToken) external {
        IMasterChef.PoolInfo poolInfo = masterChef.poolInfo(pid);

        uint256 beforeWantBalance = wantToken.balanceOf(address(this));
        uint256 beforeRewardBalance = poolInfo.rewardToken.balanceOf(address(this));

        _handleZap(pid, wantToken, IUniswapV2Pair(poolInfo.lpToken), amount, false);

        _returnAsset(wantToken, wantToken.balanceOf(address(this)).sub(beforeWantBalance), msg.sender);
        if (address(poolInfo.rewardToken) != address(wantToken)) {
            _returnAsset(poolInfo.rewardToken, poolInfo.rewardToken.balanceOf(address(this)).sub(beforeRewardBalance), msg.sender);
        }
    }

    function claim(uint256 pid) external {
        IMasterChef.PoolInfo poolInfo = masterChef.poolInfo(pid);

        uint256 beforeRewardBalance = poolInfo.rewardToken.balanceOf(address(this));

        masterChef.claim(pid);

        _returnAsset(poolInfo.rewardToken, poolInfo.rewardToken.balanceOf(address(this)).sub(beforeRewardBalance), msg.sender);
    }

    function _handleZap(
        uint256 pid,
        IERC20 wantToken,
        IUniswapV2Pair pair,
        uint256 amount,
        bool isDeposit
    ) private {
        address wantAddress = address(wantToken);
        bool isWant0 = pair.token0() == wantAddress;
        require(isWant0 || pair.token1() == wantAddress, 'Desired token not present in liquidity pair');

        address[] memory path = new address[](2);

        if (isDeposit) {
            path[0] = wantAddress;
            path[1] = address(isWant0 ? pair.token1() : pair.token0());
            
            uint256 amountLiquidity = _swapAndAddLiquidity(pair, path, amount, isWant0);

            IERC20(pair).approve(address(masterChef), amountLiquidity);
            masterChef.deposit(pid, amountLiquidity);
        } else {
            path[0] = address(isWant0 ? pair.token1() : pair.token0());
            path[1] = wantAddress;

            uint256 beforeLpBalance = IERC20(address(pair)).balanceOf(address(this));
            masterChef.withdraw(pid, amount);

            (uint256 amount0, uint256 amount1) = _removeLiquidity(
                address(pair),
                IERC20(address(pair)).balanceOf(address(this)).sub(beforeLpBalance),
                address(this)
            );

            // swap the second pair token for the want token
            _swapExactTokensForTokens(isWant0 ? amount1 : amount0, 1, path, address(this), block.timestamp);
        }
    }

    function _swapAndAddLiquidity(
        IUniswapV2Pair pair,
        address[] memory path,
        uint256 amount,
        bool isWant0
    ) private returns (uint256) {
        (uint256 reserveA, uint256 reserveB,) = pair.getReserves();
        require(reserveA > minimumAmount && reserveB > minimumAmount, 'Liquidity pair reserves too low');

        uint256 swapAmountIn;
        if (isWant0) {
            swapAmountIn = _getSwapAmount(amount, reserveA, reserveB);
        } else {
            swapAmountIn = _getSwapAmount(amount, reserveB, reserveA);
        }

        // swap the want token for the second pair token
        uint256[] memory swappedAmounts = _swapExactTokensForTokens(swapAmountIn, 1, path, address(this), block.timestamp);

        // get LP tokens
        IERC20(path[0]).approve(address(router), amount.sub(swappedAmounts[0]));
        IERC20(path[1]).approve(address(router), swappedAmounts[1]);
        (,, uint256 amountLiquidity) = router
            .addLiquidity(path[0], path[1], amount.sub(swappedAmounts[0]), swappedAmounts[1], 1, 1, address(this), block.timestamp);

        return amountLiquidity;
    }

    function _swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] memory path,
        address to,
        uint deadline
    ) private returns (uint[] memory amounts) {
        IERC20(path[0]).approve(address(router), amountIn);
        return router.swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
    }

    function _removeLiquidity(address pair, uint256 amount, address to) private returns (uint256 amount0, uint256 amount1) {
        IERC20(pair).transfer(pair, amount);
        (amount0, amount1) = IUniswapV2Pair(pair).burn(to);

        require(amount0 >= minimumAmount, 'INSUFFICIENT_A_AMOUNT');
        require(amount1 >= minimumAmount, 'INSUFFICIENT_B_AMOUNT');
    }

    function _returnAsset(IERC20 token, uint256 amount, address to) private {
        if (amount > 0) {
            if (address(token) == address(WETH)) {
                WETH.withdraw(amount);
                payable(to).send(amount);
            } else {
                token.transfer(to, amount);
            }
        }
    }

    function _getSwapAmount(
        uint256 investmentA,
        uint256 reserveA,
        uint256 reserveB
    ) private view returns (uint256 swapAmount) {
        uint256 halfInvestment = investmentA / 2;

        uint256 nominator = router.getAmountOut(halfInvestment, reserveA, reserveB);
        
        uint256 denominator = router.quote(halfInvestment, reserveA.add(halfInvestment), reserveB.sub(nominator));
        swapAmount = investmentA.sub(Babylonian.sqrt(halfInvestment * halfInvestment * nominator / denominator));
    }
}
