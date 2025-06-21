
# SimpleSwap

This contract allows for the addition and removal of liquidity, token swaps, and issues an internal LP token to represent each user's stake.
---

## Public Functions

### `addLiquidity`

```solidity
function addLiquidity(
    address tokenA,
    address tokenB,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
```

Add liquidity to the pool. If this is the first time, define the token pair. Transfer the tokens from the user and issue liquidity tokens (LP) to the recipient.

---

### `removeLiquidity`

```solidity
function removeLiquidity(
    address tokenA,
    address tokenB,
    uint256 liquidity,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
) external returns (uint256 amountA, uint256 amountB);
```

Removes liquidity from the pool. Removes and burns liquidity tokens and transfers the underlying tokens `tokenA` and `tokenB` to the user in proportion to their stake.

---

### `swapExactTokensForTokens`

```solidity
function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
) external;
```

Performs an exchange of an exact amount of `tokenIn` for `tokenOut`. `path` must contain exactly two addresses: `[tokenIn, tokenOut]`.

---

### `getPrice`

```solidity
function getPrice(address tokenA, address tokenB) external view returns (uint256 price);
```

Returns the price of `tokenA` expressed in terms of `tokenB`, calculated as the quotient of the reserves, scaled to 18 decimal places.

---

### `getAmountOut`

```solidity
function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external view returns (uint256);
```

Calculates how many tokens will be received (`amountOut`) from an input amount (`amountIn`) and current reserves.

---

## Considerations

- The token pair (`tokenA`, `tokenB`) is set with the first call to `addLiquidity`.
- The liquidity token (LP) is an internal ERC-20 token called `LIQUIDITY`.
- An `approve()` is required before the contract can move the user's tokens.
- All sensitive functions include a `deadline` to prevent untimed executions (slippage protection).


