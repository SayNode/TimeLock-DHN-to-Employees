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

    //Token
    IERC20Votes public _wDHN;

    //Events
    event ERC20Released(address indexed _token, uint256 amount);

    //Mappings
    mapping(address => Employee) public _walletToEmployee;

    //Structs
    struct Employee {
        address employee_address;// probably can take it out

        uint256 received_tokens;// amount of tokens the employee has received

        uint256 tokens_promised;// amount of tokens the employee is owed

        uint64 lock_start;// saves the date of the initial locking of the contract

        uint16 milestone;// how many milestone rewards has the employee claimed

        bool employment_status;// True-currently employed, False-no longer employed

        bool og_employee;/* 
                          saves gas by id'ing each employee as og/true (the original locked team) 
                          or new/false (new employes). This way we can just save the durations and amounts
                          in two single variables in the contract instead of saving them for each og employee
                         */
    }

    //Variables
    Employee[] _employees;// array with all the employee arrays
    uint32[]  _duration;// duration periods _duration[0]= 3 years, _duration[1]=3 years 1 month, etc
    uint256 _erc20Released;// total amount of released tokens
    uint256 numMilestones;// number of milestones (number of payments for each employee)
    uint256 _OGTeamTokens;// tokens that belong to the OG team
    uint256 _numOGEmployees;// number of OG employess
    uint256 _leftover;// tokens destined to new employess
    address _token;// token address

    //Functions
    /**
     * @dev Set the beneficiary, start timestamp and locking durations and amounts.
     */
    constructor(
        IERC20Votes wDHN,
        uint256 numMilestones,
        uint256 ogTeamTokens,
        address tokenAdress,
        address[] memory lockedTeamAddresses,
        address[] memory duration,
        uint256[] lockedTeamTokens
    ) {

        // number of milestones
        _numMilestones = numMilestones;

        // number of OG employees
        _numOGEmployees = lockedTeamAddresses.length;

        // get the number of tokens destined for the OG team
        _OGTeamTokens = ogTeamTokens;

        // create an employee struct for each OG employee
        for (i=0; i<lockedTeamAddresses.length; i++){

            // employee address can't be the zero address
            require(lockedTeamAddresses[i] != address(0), "Constructor: locked team address is zero address");

            // create the new employee struct
            Employee memory employee = Employee(lockedTeamAddresses[i], 0, uint64(block.timestamp), true, true);

            // push the new employee struct to the employees array
            _employees.push(employee);

            // map the new employee address to its struct
            _walletToEmployee[lockedTeamAddresses[i]]=employee;

            // get the amount of tokens that belong to each og employee
            uint256 _amount = _OGTeamTokens/(_numOGEmployees);

            // delegate future token votes, to the employee
            delegate_to_employee(msg.sender, _amount);
        }

        // establish token address
        _token = tokenAdress;
        _wDHN = wDHN;

        // establish the durations periods 
        _duration = duration;
    }


    /**
     * @dev Modifier that only allows current employess to interact with certain functions
     */
    modifier onlyEmployees(address callerAddress){
        require(_walletToEmployee[callerAddress].employment_status == true, 'This address is no a current employee');
        _;
    }


    /**
     * @dev Calculates the date of the next milestone (used to see if the milestone has passed or not)
     * --TO DO: remove the if stament, possibly only needed line 136 
     * (need to see if 30 days can be multiplied by zero)
     */
    function get_date(address _callerAddress) public view virtual returns (uint256) {

        // get the last milestone the employee received
        uint16 currentMileStone = _walletToEmployee[_callerAddress].milestone;
        // get the time the lock period began for this employee
        uint64 lock_start = _walletToEmployee[_callerAddress].lock_start;

    	// if it is the first milestone
        if(currentMileStone==0){
            // ... the date is equal to the locking start date + the lock time (2 years)
            uint256 date = lock_start + _duration[0];
        }else{
            /* 
             ... otherwise the date is equal to the locking start date + the lock 
             time (2 years) + a month for each milestone already retrived
            */
            uint256 date = lock_start + _duration[0]+ (30 days)*currentMileStone;
        }

        // return the date of the next milestone 
        return _duration[currentMileStone];
    }


    /**
     * @dev Release the tokens according to milestone passage.
     *
     * Emits a {ERC20Released} event.
     */
    function release() public virtual onlyEmployees(msg.sender){
        uint256 releasable = _vestingSchedule(msg.sender, uint64(block.timestamp));
        _erc20Released += releasable;
        emit ERC20Released(_token, releasable);
        SafeERC20.safeTransfer(IERC20(_token), msg.sender, releasable);
    }


    /**
     * @dev This returns the amount of tokens that can be withdrawn, as function of milestones passed.
     */
    function _vestingSchedule(address _callerAddress, uint64 timestamp) internal virtual returns (uint256) {
        // get the last milestone the employee received
        uint16 currentMileStone = _walletToEmployee[_callerAddress].milestone;

        require(currentMileStone < _numMilestones, "All milestone rewards have been claimed");

        //If the time is superior to the current milestone duration...
        if (timestamp > get_date(_callerAddress)) {
            //...we save the the amount we can withdraw in this milestone.

            // get the amount of tokens that belong to each employee
            uint256 can_withdraw = _walletToEmployee[_callerAddress].tokens_promised/(_numMilestones);

            //Increment the milestone of a particular employee (if it is not the last milestone)
            _walletToEmployee[_callerAddress].milestone = _walletToEmployee[_callerAddress].milestone+1;

            //Return the amount to withdraw this milestone
            return can_withdraw;

        } else {
            return 0;
        }
    }

    /**
     * @dev Adds a new employee. --TO DO: See how the split enters--
     */
    function new_employee(uint256 amount) public {
            // create the new employee struct
            Employee memory employee = Employee(msg.sender, 0, uint64(block.timestamp), true, false);

            // push the new employee struct to the employees array
            _employees.push(employee);

            // map the new employee address to its struct
            _walletToEmployee[msg.sender]=employee;

            // delegate future token votes, to the employee
            _wDHN.delegate(_employee, amount);
    }

    /**
     * @dev Changes the employee status of an employee who is quitting. --TO DO: Make multi-sig--
     */
    function remove_employee(address employeeAddress) public {
        _walletToEmployee[employeeAddress].employment_status = false;
    }

    /**
     * @dev Delegates the voting power to the
     */
    function delegate_to_employee(address employee, uint256 amount) internal {
        _wDHN.delegate(employee, amount);
    }
}