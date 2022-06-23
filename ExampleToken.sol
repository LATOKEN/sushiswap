// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./utils/AccessControl.sol";
import "./utils/Context.sol";
import "./utils/ERC20Burnable.sol";
import "./utils/ERC20Pausable.sol";

/**
 * @dev {ERC20} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - a pauser role that allows to stop all token transfers
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 */
contract ExampleToken is Context, AccessControl, ERC20Burnable, ERC20Pausable {
    // bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    // bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    //only for wLA
    // event Deposit(address user, uint256 amount);
    // event Withdrawal(address user, uint256 amount);

    constructor () public {
        _roles[msg.sender] = true;
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 amount) public virtual {
        require(hasRole(_msgSender()));
        _mint(to, amount);
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public virtual {
        require(hasRole(_msgSender()));
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public virtual {
        require(hasRole(_msgSender()));
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    //only for wLA
    // function deposit() public payable {
    //     _mint(msg.sender, msg.value);
    //     emit Deposit(msg.sender, msg.value);
    // }

    // function withdraw(uint256 wad) public {
    //     require(_balances[msg.sender] >= wad);
    //     // _balances[_msgSender()] = _balances[_msgSender()] - wad;
    //     // _totalSupply = _totalSupply - wad;
    //     _burn(msg.sender, wad);
    //     msg.sender.transfer(wad);
    //     emit Withdrawal(msg.sender, wad);
    //     // emit Transfer(_msgSender(), address(0), wad);
    // }
}
