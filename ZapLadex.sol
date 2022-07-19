// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./libraries/Babylonian.sol";
import "./libraries/SafeMath.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}

contract ZapLadex {
    using SafeMath for uint256;

    address constant WETH = address(0xe66c9c4D573eDD86468F95F0B636719044708F92);
    address constant router = address(0xeeF9F2eC6cC2eCbeF0003bb5606C81B16cf24943);

    function deposit(IUniswapV2Pair _pair, address _depositToken, uint256 _amount) external payable returns (uint256) {
        uint256 beforeLpTokenBalance = IERC20(_pair).balanceOf(address(this));

        if (_depositToken == WETH) {
            IWETH(WETH).deposit{value: _amount}();
        } else {
            IERC20(_depositToken).transferFrom(
                msg.sender,
                address(this),
                _amount
            );
        }
        zap(_pair, _depositToken, _amount, true);

        return IERC20(_pair).balanceOf(address(this)).sub(beforeLpTokenBalance);
    }

    function withdraw(IUniswapV2Pair _pair, address _depositToken, uint256 _amount) external {
        zap(_pair, _depositToken, _amount, false);
    }

    function zap(
        IUniswapV2Pair _pair,
        address _depositToken,
        uint256 _amount,
        bool _isDeposit
    ) internal {
        bool isWant0 = _pair.token0() == _depositToken;
        require(isWant0 || _pair.token1() == _depositToken, 'Desired token not present in liquidity pair');

        address[] memory path = new address[](2);
        uint256 beforeDepositTokenBalance = IERC20(_depositToken).balanceOf(address(this));

        if (_isDeposit) {
            path[0] = _depositToken;
            path[1] = address(isWant0 ? _pair.token1() : _pair.token0());

            uint256 swapAmountIn;
            (uint256 reserveA, uint256 reserveB,) = _pair.getReserves();
            if (isWant0) {
                swapAmountIn = getSwapAmount(_amount, reserveA, reserveB);
            } else {
                swapAmountIn = getSwapAmount(_amount, reserveB, reserveA);
            }

            uint256[] memory swappedAmounts = swapExactTokensForTokens(swapAmountIn, 1, path, address(this), block.timestamp);

            IERC20(path[0]).approve(router, _amount.sub(swappedAmounts[0]));
            IERC20(path[1]).approve(router, swappedAmounts[1]);
            (,,) = IUniswapV2Router(router).addLiquidity(path[0], path[1], _amount.sub(swappedAmounts[0]), swappedAmounts[1], 1, 1, address(this), block.timestamp);
        
            beforeDepositTokenBalance = beforeDepositTokenBalance.sub(_amount);
        } else {
            path[0] = address(isWant0 ? _pair.token1() : _pair.token0());
            path[1] = _depositToken;

            IERC20(_pair).transfer(address(_pair), _amount);
            (uint256 amount0, uint256 amount1) = _pair.burn(address(this));

            swapExactTokensForTokens(isWant0 ? amount1 : amount0, 1, path, address(this), block.timestamp);
        }

        returnAsset(_depositToken, IERC20(_depositToken).balanceOf(address(this)).sub(beforeDepositTokenBalance), msg.sender);
    }

    function swapExactTokensForTokens(
        uint _amountIn,
        uint _amountOutMin,
        address[] memory _path,
        address _to,
        uint _deadline
    ) internal returns (uint[] memory) {
        IERC20(_path[0]).approve(router, _amountIn);
        return IUniswapV2Router(router).swapExactTokensForTokens(_amountIn, _amountOutMin, _path, _to, _deadline);
    }

    function returnAsset(
        address _token,
        uint256 _amount,
        address _to
    ) internal {
        if (_amount > 0) {
            if (_token == WETH) {
                IWETH(WETH).withdraw(_amount);
                payable(_to).send(_amount);
            } else {
                IERC20(_token).transfer(_to, _amount);
            }
        }
    }

    function getSwapAmount(
        uint256 _investmentA,
        uint256 _reserveA,
        uint256 _reserveB
    ) internal view returns (uint256 swapAmount) {
        uint256 halfInvestment = _investmentA / 2;

        uint256 nominator = IUniswapV2Router(router).getAmountOut(halfInvestment, _reserveA, _reserveB);
        
        uint256 denominator = IUniswapV2Router(router).quote(halfInvestment, _reserveA.add(halfInvestment), _reserveB.sub(nominator));
        swapAmount = _investmentA.sub(Babylonian.sqrt(halfInvestment * halfInvestment * nominator / denominator));
    }
}
