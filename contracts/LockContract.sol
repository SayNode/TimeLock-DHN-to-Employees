// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (finance/LockContract.sol)
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title LockContract
 * @dev This contract handles the vesting of a ERC20 tokens for a given beneficiary. Custody of the token amount
 * can be given to this contract, which will release the token to the beneficiary following a given schedule.
 * The vesting schedule is established by a key->value pair in the form of _duration->_amounts. This two arrays
 * have the same length and are iterated by the _milestone variable
 */
contract LockContract is Context {

    event ERC20Released(address indexed token, uint256 amount);

    mapping(address => uint256) private _erc20Released;
    mapping(address => Employee) public _walletToEmployee;

    struct Employee {
        address employee_address;
        uint tokens_to_receive;
        uint received_tokens;
        bool employment_status;
    }

    address token;
    Employee[] employees;
    uint32[]  _duration;
    uint256[] _amounts;
    uint256 _released;
    uint _lockedTeamTokens;



    /**
     * @dev Set the beneficiary, start timestamp and locking durations and amounts.
     */
    constructor(
        address tokenAdress,
        address[] memory lockedTeamAddresses,
        address[] memory duration,
        uint256 lockedTeamTokens
    ) {
        for (i=0; i<lockedTeamAddresses.length; i++){
            require(lockedTeamAddresses[i] != address(0), "Constructor: locked team address is zero address");
            employees.push(Employee(lockedTeamAddresses[i], lockedTeamTokens, 0, true));
        }

        token = tokenAdress;
        _duration = duration;
        _lockedTeamTokens = lockedTeamTokens;
    }



    /**
     * @dev Getter for the end date of the current milestone.
     */
    function duration() public view virtual returns (uint256) {
        return _duration[_mileStone];
    }


    /**
     * @dev Amount of token already released
     */
    function released() public view virtual returns (uint256) {
        return _erc20Released[token];
    }

    /**
     * @dev Release the tokens according to milestone passage.
     *
     * Emits a {ERC20Released} event.
     */
    function release() public virtual {
        uint256 releasable = _vestingSchedule(uint64(block.timestamp));
        _erc20Released[token] += releasable;
        emit ERC20Released(token, releasable);
        SafeERC20.safeTransfer(IERC20(token), beneficiary(), releasable);
    }


    /**
     * @dev This returns the amount of tokens that can be withdrawn, as function of milestones passed.
     */
    function _vestingSchedule( uint64 timestamp) internal virtual returns (uint256) {
        require(_mileStone< _amounts.length, "All milestone rewards have been claimed");
        //If the time is superior to the current milestone duration...
        if (timestamp > duration()) {
            //...we save the the amount we can withdraw in this milestone.
            uint256 can_withdraw = _amounts[_mileStone];

            //Increment the milesonte (if it is not the last milestone)
            _mileStone=_mileStone+1;
            //Return the amount to withdraw this milestone
            return can_withdraw;

        } else {
            return 0;
        }
    }
}