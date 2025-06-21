// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract HTokenA is ERC20, ERC20Burnable, ERC20Pausable, Ownable {
    constructor(address recipient, address initialOwner)
        ERC20("HTokenA", "HTA")
        Ownable(initialOwner)
    {
        _mint(recipient, 150 * 10 ** decimals());
    }

    function pause() public  {
        _pause();
    }

    function unpause() public  {
        _unpause();
    }

    function mint(address to, uint256 amount) public  {
        _mint(to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}
