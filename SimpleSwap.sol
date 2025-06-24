// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// @title SimpleSwap
/// @dev Inherits ERC20 to represent LP tokens. Tokens are set at first addLiquidity call.
contract SimpleSwap is ERC20 {
    using SafeERC20 for IERC20;

    /// @notice Token A address (set at first liquidity addition)
    address public tokenAAddres;
    /// @notice Token B address (set at first liquidity addition)
    address public tokenBAddres;

    /// @notice Current reserve of token A
    uint256 public reserveA;
    /// @notice Current reserve of token B
    uint256 public reserveB;

    /// @dev Initializes LP token with name and symbol
    constructor() ERC20("LIQUIDITY", "LP") {}

    /// @notice Adds liquidity to the pool and mints LP tokens
    /// @param tokenA Address of token A
    /// @param tokenB Address of token B
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
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(block.timestamp <= deadline, "Expired");

        address _tokenAAddres = tokenAAddres;
        address _tokenBAddres = tokenBAddres;

        if (_tokenAAddres == address(0) && _tokenBAddres == address(0)) {
            require(tokenA != tokenB, "Tokens must differ");
            tokenAAddres = tokenA;
            tokenBAddres = tokenB;
            _tokenAAddres = tokenA;
            _tokenBAddres = tokenB;
        } else {
            require(
                (tokenA == _tokenAAddres && tokenB == _tokenBAddres) ||
                (tokenA == _tokenBAddres && tokenB == _tokenAAddres),
                "Invalid token pair"
            );
        }

        uint256 _reserveA = reserveA;
        uint256 _reserveB = reserveB;
        uint256 _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
            liquidity = Math.sqrt(amountA * amountB);
        } else {
            amountA = amountADesired;
            amountB = (amountA * _reserveB) / _reserveA;
            require(amountB <= amountBDesired, "Too much B");
            liquidity = (amountA * _totalSupply) / _reserveA;
        }

        require(amountA >= amountAMin, "Low A");
        require(amountB >= amountBMin, "Low B");
        require(liquidity > 0, "Zero liquidity");

        IERC20(_tokenAAddres).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(_tokenBAddres).safeTransferFrom(msg.sender, address(this), amountB);

        reserveA = _reserveA + amountA;
        reserveB = _reserveB + amountB;
        _mint(to, liquidity);
    }

    /// @notice Removes liquidity and burns LP tokens
    /// @param tokenA Address of token A
    /// @param tokenB Address of token B
    /// @param liquidity Amount of LP tokens to burn
    /// @param amountAMin Minimum amount of token A to receive
    /// @param amountBMin Minimum amount of token B to receive
    /// @param to Address receiving the underlying tokens
    /// @param deadline Timestamp after which transaction is invalid
    /// @return amountA Amount of token A returned
    /// @return amountB Amount of token B returned
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        require(block.timestamp <= deadline, "Expired");

        address _tokenAAddres = tokenAAddres;
        address _tokenBAddres = tokenBAddres;

        require(
            (tokenA == _tokenAAddres && tokenB == _tokenBAddres) ||
            (tokenA == _tokenBAddres && tokenB == _tokenAAddres),
            "Invalid token pair"
        );

        uint256 _reserveA = reserveA;
        uint256 _reserveB = reserveB;
        uint256 _totalSupply = totalSupply();

        require(balanceOf(msg.sender) >= liquidity, "Not enough LP");

        amountA = (liquidity * _reserveA) / _totalSupply;
        amountB = (liquidity * _reserveB) / _totalSupply;

        require(amountA >= amountAMin, "Low A");
        require(amountB >= amountBMin, "Low B");

        _burn(msg.sender, liquidity);

        reserveA = _reserveA - amountA;
        reserveB = _reserveB - amountB;

        IERC20(_tokenAAddres).safeTransfer(to, amountA);
        IERC20(_tokenBAddres).safeTransfer(to, amountB);
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

        address _tokenAAddres = tokenAAddres;
        address _tokenBAddres = tokenBAddres;

        require(
            (tokenIn == _tokenAAddres && tokenOut == _tokenBAddres) ||
            (tokenIn == _tokenBAddres && tokenOut == _tokenAAddres),
            "Invalid swap path"
        );

        (uint256 reserveIn, uint256 reserveOut) = tokenIn == _tokenAAddres
            ? (reserveA, reserveB)
            : (reserveB, reserveA);

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        uint256 amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
        require(amountOut >= amountOutMin, "Slippage");

        if (tokenIn == _tokenAAddres) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        IERC20(tokenOut).safeTransfer(to, amountOut);
    }

    /// @notice Returns the price of tokenA in terms of tokenB
    /// @param tokenA Address
    /// @param tokenB Address
    /// @return price Price with 18 decimals (tokenB per tokenA)
    function getPrice(address tokenA, address tokenB) external view returns (uint256 price) {
        address _tokenAAddres = tokenAAddres;
        address _tokenBAddres = tokenBAddres;

        require(
            (tokenA == _tokenAAddres && tokenB == _tokenBAddres) ||
            (tokenA == _tokenBAddres && tokenB == _tokenAAddres),
            "Invalid token pair"
        );

        uint256 _reserveA = reserveA;
        uint256 _reserveB = reserveB;

        require(_reserveA > 0 && _reserveB > 0, "No reserves");

        price = (_reserveB * 1e18) / _reserveA;
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