// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (finance/LockContract.sol)
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/_token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title LockContract
 * @dev This contract handles the vesting of a ERC20 tokens for a given beneficiary. Custody of the _token amount
 * can be given to this contract, which will release the _token to the beneficiary following a given schedule.
 * The vesting schedule is established by a key->value pair in the form of _duration->_amounts. This two arrays
 * have the same length and are iterated by the _milestone variable
 */
contract LockContract is Context {

    //Events
    event ERC20Released(address indexed _token, uint256 amount);

    //Mappings
    mapping(address => uint256) private _erc20Released;
    mapping(address => Employee) public _walletToEmployee;

    //Structs
    struct Employee {
        address employee_address;//Probably can take it out

        uint received_tokens;//Amount of tokens the employee has received

        uint64 lock_start;//Saves the date of the initial locking of the contract

        bool employment_status;//True-currently employed, False-no longer employed

        bool og_employee;//Saves gas by id'ing each employee as og/true (the original locked team) 
                         //or new/false (new employes). This way we can just save the durations and amounts
                         //in two single variables in the contract instead of saving them for each og employee
    }

    //Variables
    Employee[] _employees;
    uint32[]  _duration;//Duration periods _duration[0]= 3 years, _duration[1]=3 years 1 month, etc
    uint256 _released;
    uint256 _lockedTeamTokens;
    uint256 _mileStone;
    address _token;



    /**
     * @dev Set the beneficiary, start timestamp and locking durations and amounts.
     */
    constructor(
        address tokenAdress,
        address[] memory lockedTeamAddresses,
        address[] memory duration,
        uint256[] lockedTeamTokens
    ) {
        // create an employee struct for each OG employee
        for (i=0; i<lockedTeamAddresses.length; i++){

            // employee address can't be the zero address
            require(lockedTeamAddresses[i] != address(0), "Constructor: locked team address is zero address");

            // create the new employee struct
            Employee memory employee = Employee(lockedTeamAddresses[i], 0, uint64(block.timestamp), true, true);

            // push the new employee struct to the employees array
            _employees.push(employee);

            // map the new employee address to its struct
            _walletToEmployee[msg.sender]=employee;
        }

        // establish token address
        _token = tokenAdress;

        // establish the durations periods 
        _duration = duration;
    }


    /**
     * @dev Modifier that only allows current employess to interact with certain functions
     */
    modifier onlyEmployees(address _callerAddress){
        require(_walletToEmployee[_callerAddress].employment_status == true, 'This address is no a current employee');
        _;
    }


    /**
     * @dev Getter for the end date of the current milestone.
     */
    function duration() public view virtual returns (uint256) {
        return _duration[_mileStone];
    }


    /**
     * @dev Amount of _token already released
     */
    function released() public view virtual returns (uint256) {
        return _erc20Released[_token];
    }

    /**
     * @dev Release the tokens according to milestone passage.
     *
     * Emits a {ERC20Released} event.
     */
    function release() public virtual onlyEmployees(msg.sender){
        uint256 releasable = _vestingSchedule(uint64(block.timestamp));
        _erc20Released[_token] += releasable;
        emit ERC20Released(_token, releasable);
        SafeERC20.safeTransfer(IERC20(_token), msg.sender, releasable);
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