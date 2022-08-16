// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "./ERC20.sol";

contract ERC20Token is ERC20 {

    address _owner;
    uint256 immutable _cap;

    constructor(uint256 cap_, string memory name, string memory symbol) ERC20(name, symbol) {
        _owner = msg.sender;
        _cap = cap_;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Not the owner of the contract!");
        _;
    }

    function cap() public view returns (uint256) {
        return _cap;
    }

    function mint(address account, uint256 amount) external onlyOwner {
        require(ERC20.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        super._mint(account, amount);
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(_msgSender(), amount);
    }

}
