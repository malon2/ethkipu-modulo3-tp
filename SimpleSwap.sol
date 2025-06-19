// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// @title SimpleSwap - A simplified Uniswap-like contract
/// @notice Allows adding/removing liquidity and swapping between two ERC-20 tokens
contract SimpleSwap {
    using SafeERC20 for IERC20;

    struct Reserve {
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        mapping(address => uint256) liquidity;
    }

    mapping(bytes32 => Reserve) private reserves;

    event LiquidityAdded(address indexed provider, address tokenA, address tokenB, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, address tokenA, address tokenB, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed sender, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    modifier ensure(uint deadline) {
        require(block.timestamp <= deadline, "Transaction expired");
        _;
    }

    function _getPairKey(address tokenA, address tokenB) private pure returns (bytes32) {
        return tokenA < tokenB ? keccak256(abi.encodePacked(tokenA, tokenB)) : keccak256(abi.encodePacked(tokenB, tokenA));
    }

    function _sortTokens(address tokenA, address tokenB) private pure returns (address, address) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /// @notice Add liquidity to a pool
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        require(tokenA != tokenB, "Identical tokens");

        bytes32 pairKey = _getPairKey(tokenA, tokenB);
        Reserve storage r = reserves[pairKey];

        (amountA, amountB) = _quoteAddLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            r.reserveA,
            r.reserveB,
            r.totalLiquidity
        );

        _transferTokens(tokenA, tokenB, amountA, amountB);
        liquidity = _calculateLiquidity(amountA, amountB, r.reserveA, r.reserveB, r.totalLiquidity);
        require(liquidity > 0, "Insufficient liquidity minted");

        r.reserveA += amountA;
        r.reserveB += amountB;
        r.totalLiquidity += liquidity;
        r.liquidity[to] += liquidity;

        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB, liquidity);
    }

    function _quoteAddLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        uint reserveA,
        uint reserveB,
        uint totalLiquidity
    ) internal pure returns (uint amountA, uint amountB) {
        if (totalLiquidity == 0) {
            return (amountADesired, amountBDesired);
        }

        (address token0,) = _sortTokens(tokenA, tokenB);
        (uint rA, uint rB) = tokenA == token0 ? (reserveA, reserveB) : (reserveB, reserveA);

        uint bOptimal = (amountADesired * rB) / rA;
        if (bOptimal <= amountBDesired) {
            require(bOptimal >= amountBMin, "Insufficient B amount");
            return (amountADesired, bOptimal);
        } else {
            uint aOptimal = (amountBDesired * rA) / rB;
            require(aOptimal >= amountAMin, "Insufficient A amount");
            return (aOptimal, amountBDesired);
        }
    }

    function _transferTokens(address tokenA, address tokenB, uint amountA, uint amountB) internal {
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);
    }

    function _calculateLiquidity(
        uint amountA,
        uint amountB,
        uint reserveA,
        uint reserveB,
        uint totalLiquidity
    ) internal pure returns (uint liquidity) {
        if (totalLiquidity == 0) {
            liquidity = Math.sqrt(amountA * amountB);
        } else {
            liquidity = Math.min(
                (amountA * totalLiquidity) / reserveA,
                (amountB * totalLiquidity) / reserveB
            );
        }
    }

function _calculateAmounts(
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    uint reserveA,
    uint reserveB,
    uint totalLiquidity
) internal pure returns (uint amountA, uint amountB) {
    if (totalLiquidity == 0) {
        return (amountADesired, amountBDesired);
    }

    (address token0,) = _sortTokens(tokenA, tokenB);
    (uint rA, uint rB) = tokenA == token0 ? (reserveA, reserveB) : (reserveB, reserveA);

    uint bOptimal = (amountADesired * rB) / rA;
    if (bOptimal <= amountBDesired) {
        require(bOptimal >= amountBMin, "Insufficient B amount");
        amountA = amountADesired;
        amountB = bOptimal;
    } else {
        uint aOptimal = (amountBDesired * rA) / rB;
        require(aOptimal >= amountAMin, "Insufficient A amount");
        amountA = aOptimal;
        amountB = amountBDesired;
    }
}




    /// @notice Remove liquidity from a pool
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB) {
        bytes32 pairKey = _getPairKey(tokenA, tokenB);
        Reserve storage r = reserves[pairKey];

        require(r.liquidity[msg.sender] >= liquidity, "Insufficient liquidity");

        amountA = (liquidity * r.reserveA) / r.totalLiquidity;
        amountB = (liquidity * r.reserveB) / r.totalLiquidity;

        require(amountA >= amountAMin, "Insufficient A amount");
        require(amountB >= amountBMin, "Insufficient B amount");

        r.reserveA -= amountA;
        r.reserveB -= amountB;
        r.totalLiquidity -= liquidity;
        r.liquidity[msg.sender] -= liquidity;

        IERC20(tokenA).safeTransfer(to, amountA);
        IERC20(tokenB).safeTransfer(to, amountB);

        emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB, liquidity);
    }

    /// @notice Swap exact tokens for tokens
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint[] memory amounts) {
        require(path.length == 2, "Only 2-token path supported");

        address tokenIn = path[0];
        address tokenOut = path[1];

        bytes32 pairKey = _getPairKey(tokenIn, tokenOut);
        Reserve storage r = reserves[pairKey];

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        (uint reserveIn, uint reserveOut) = tokenIn < tokenOut
            ? (r.reserveA, r.reserveB)
            : (r.reserveB, r.reserveA);

        uint amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "Insufficient output amount");

        // actualizamos reservas
        if (tokenIn < tokenOut) {
            r.reserveA += amountIn;
            r.reserveB -= amountOut;
        } else {
            r.reserveB += amountIn;
            r.reserveA -= amountOut;
        }

        IERC20(tokenOut).safeTransfer(to, amountOut);

        amounts = new uint[](2) ;
        amounts[0] = amountIn;
        amounts[1] = amountOut;

        // emit con menos variables directamente
        emit Swap(msg.sender, tokenIn, tokenOut, amounts[0], amounts[1]);
    }


    /// @notice Get price of tokenA in terms of tokenB
    function getPrice(address tokenA, address tokenB) external view returns (uint price) {
        bytes32 pairKey = _getPairKey(tokenA, tokenB);
        Reserve storage r = reserves[pairKey];
        (uint reserveA, uint reserveB) = tokenA < tokenB ? (r.reserveA, r.reserveB) : (r.reserveB, r.reserveA);
        require(reserveA > 0 && reserveB > 0, "No reserves");
        return (reserveB * 1e18) / reserveA;
    }

    /// @notice Get output amount given input and reserves
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }
}
