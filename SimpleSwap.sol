// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// @title SimpleSwap
/// @notice Automated Market Maker (AMM) supporting a single token pair with internal LP token.
/// @dev Inherits ERC20 to represent LP tokens. Tokens are set at first addLiquidity call.
contract SimpleSwap is ERC20 {
    using SafeERC20 for IERC20;

    /// @notice Token A address (set at first liquidity addition)
    address public tokenA;
    /// @notice Token B address (set at first liquidity addition)
    address public tokenB;

    /// @notice Current reserve of token A
    uint256 public reserveA;
    /// @notice Current reserve of token B
    uint256 public reserveB;

    /// @dev Initializes LP token with name and symbol
    constructor() ERC20("LIQUIDITY", "LP") {}

    /// @notice Adds liquidity to the pool and mints LP tokens
    /// @param _tokenA Address of token A
    /// @param _tokenB Address of token B
    /// @param amountADesired Desired amount of token A to deposit
    /// @param amountBDesired Desired amount of token B to deposit
    /// @param amountAMin Minimum acceptable amount of token A
    /// @param amountBMin Minimum acceptable amount of token B
    /// @param to Address receiving LP tokens
    /// @param deadline Timestamp after which transaction is invalid
    /// @return amountA Actual amount of token A deposited
    /// @return amountB Actual amount of token B deposited
    /// @return liquidity Amount of LP tokens minted
    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(block.timestamp <= deadline, "Expired");

        if (tokenA == address(0) && tokenB == address(0)) {
            require(_tokenA != _tokenB, "Tokens must differ");
            tokenA = _tokenA;
            tokenB = _tokenB;
        } else {
            require(
                (_tokenA == tokenA && _tokenB == tokenB) ||
                (_tokenA == tokenB && _tokenB == tokenA),
                "Invalid token pair"
            );
        }

        if (totalSupply() == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
            liquidity = Math.sqrt(amountA * amountB);
        } else {
            amountA = amountADesired;
            amountB = (amountA * reserveB) / reserveA;
            require(amountB <= amountBDesired, "Too much B");
            liquidity = (amountA * totalSupply()) / reserveA;
        }

        require(amountA >= amountAMin, "Low A");
        require(amountB >= amountBMin, "Low B");
        require(liquidity > 0, "Zero liquidity");

        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);

        reserveA += amountA;
        reserveB += amountB;
        _mint(to, liquidity);
    }

    /// @notice Removes liquidity and burns LP tokens
    /// @param _tokenA Address of token A
    /// @param _tokenB Address of token B
    /// @param liquidity Amount of LP tokens to burn
    /// @param amountAMin Minimum amount of token A to receive
    /// @param amountBMin Minimum amount of token B to receive
    /// @param to Address receiving the underlying tokens
    /// @param deadline Timestamp after which transaction is invalid
    /// @return amountA Amount of token A returned
    /// @return amountB Amount of token B returned
    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        require(block.timestamp <= deadline, "Expired");
        require(
            (_tokenA == tokenA && _tokenB == tokenB) ||
            (_tokenA == tokenB && _tokenB == tokenA),
            "Invalid token pair"
        );

        uint256 totalLiq = totalSupply();
        require(balanceOf(msg.sender) >= liquidity, "Not enough LP");

        amountA = (liquidity * reserveA) / totalLiq;
        amountB = (liquidity * reserveB) / totalLiq;

        require(amountA >= amountAMin, "Low A");
        require(amountB >= amountBMin, "Low B");

        _burn(msg.sender, liquidity);
        reserveA -= amountA;
        reserveB -= amountB;

        IERC20(tokenA).safeTransfer(to, amountA);
        IERC20(tokenB).safeTransfer(to, amountB);
    }

    /// @notice Swaps an exact amount of input tokens for output tokens
    /// @param amountIn Amount of input token to send
    /// @param amountOutMin Minimum acceptable amount of output token
    /// @param path Array with [tokenIn, tokenOut] addresses
    /// @param to Address to receive the output token
    /// @param deadline Timestamp after which transaction is invalid
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        require(block.timestamp <= deadline, "Expired");
        require(path.length == 2, "Only 2-token swaps");

        address tokenIn = path[0];
        address tokenOut = path[1];

        require(
            (tokenIn == tokenA && tokenOut == tokenB) ||
            (tokenIn == tokenB && tokenOut == tokenA),
            "Invalid swap path"
        );

        (uint256 reserveIn, uint256 reserveOut) = tokenIn == tokenA
            ? (reserveA, reserveB)
            : (reserveB, reserveA);

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // No fee: constant product formula without 0.3% deduction
        uint256 amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);

        require(amountOut >= amountOutMin, "Slippage");

        if (tokenIn == tokenA) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        IERC20(tokenOut).safeTransfer(to, amountOut);
    }

    /// @notice Returns the price of tokenA in terms of tokenB
    /// @param _tokenA Address of token A
    /// @param _tokenB Address of token B
    /// @return price Price with 18 decimals (tokenB per tokenA)
    function getPrice(address _tokenA, address _tokenB) external view returns (uint256 price) {
        require(
            (_tokenA == tokenA && _tokenB == tokenB) ||
            (_tokenA == tokenB && _tokenB == tokenA),
            "Invalid token pair"
        );
        require(reserveA > 0 && reserveB > 0, "No reserves");
        price = (reserveB * 1e18) / reserveA;
    }

    /// @notice Computes output amount for a given input and reserves
    /// @param amountIn Amount of input token
    /// @param reserveIn Reserve of input token
    /// @param reserveOut Reserve of output token
    /// @return Output token amount
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256)
    {
        require(amountIn > 0, "Zero input");
        require(reserveIn > 0 && reserveOut > 0, "Empty reserves");
        return (amountIn * reserveOut) / (reserveIn + amountIn);
    }
}
