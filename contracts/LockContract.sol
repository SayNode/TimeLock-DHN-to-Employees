// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (finance/LockContract.sol)
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IERC20VotesAltered.sol";
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
    IERC20VotesAltered public _wDHN;

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
    uint256  _initLock;// initial lock period (2 years)
    uint256 _erc20Released;// total amount of released tokens
    uint256 _numMilestones;// number of milestones (number of payments for each employee)
    uint256 _OGTeamTokens;// tokens that belong to the OG team
    uint256 _numOGEmployees;// number of OG employess
    uint256 _leftover;// tokens destined to new employess
    address _token;// token address

    //Functions
    /**
     * @dev Set the beneficiary, start timestamp and locking durations and amounts.
     */
    constructor(
        IERC20VotesAltered wDHN,
        uint256 numMilestones,
        uint256 ogTeamTokens,
        uint256 initLock,
        address tokenAdress,
        address[] memory lockedTeamAddresses,
        uint256[] memory lockedTeamTokens
    ) {

        _wDHN=wDHN;
        // number of milestones
        _numMilestones = numMilestones;

        // number of OG employees
        _numOGEmployees = lockedTeamAddresses.length;

        // get the number of tokens destined for the OG team
        _OGTeamTokens = ogTeamTokens;

        // create an employee struct for each OG employee
        for (uint i=0; i<lockedTeamAddresses.length; i++){

            // employee address can't be the zero address
            require(lockedTeamAddresses[i] != address(0), "Constructor: locked team address is zero address");

            // get the amount of tokens that belong to each og employee
            uint256 _amount = _OGTeamTokens/(_numOGEmployees);

            // create the new employee struct
            Employee memory employee = Employee(lockedTeamAddresses[i], 0, _amount, uint64(block.timestamp), 0, true, true);

            // push the new employee struct to the employees array
            _employees.push(employee);

            // map the new employee address to its struct
            _walletToEmployee[lockedTeamAddresses[i]]=employee;

            // delegate future token votes, to the employee
            delegate_votes(lockedTeamAddresses[i], _amount);
        }

        // establish token address
        _token = tokenAdress;
        _wDHN = wDHN;

        // establish the durations periods 
        _initLock = initLock;
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

        /* the date is equal to the locking start date + the lock 
         time (2 years) + a month for each milestone already retrived
        */
        uint256 milestone_date = lock_start + _initLock+ (30 days)*currentMileStone;
        
        // return the date of the next milestone 
        return milestone_date;
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
        _walletToEmployee[msg.sender].received_tokens += releasable;
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
    function new_employee(uint256 amount, address new_employee_address) public {
            // create the new employee struct
            Employee memory employee = Employee(new_employee_address, 0, amount, uint64(block.timestamp),0, true, false);

            // push the new employee struct to the employees array
            _employees.push(employee);

            // map the new employee address to its struct
            _walletToEmployee[new_employee_address]=employee;

            // delegate future token votes, to the employee
            _wDHN.delegate(new_employee_address, amount);
    }

    /**
     * @dev Changes the employee status of an employee who is quitting. --TO DO: Make multi-sig--
     */
    function remove_employee(address employeeAddress) public {

        //give the employee his owed tokens
        uint256 releasable = _vestingSchedule(employeeAddress, uint64(block.timestamp));
        _erc20Released += releasable;
        emit ERC20Released(_token, releasable);
        SafeERC20.safeTransfer(IERC20(_token), employeeAddress, releasable);

        //get the votes that will have to be delegated back to the contract:
                        // tokens_promised-tokens.received
        uint256 votes_back_to_contract = _walletToEmployee[lockedTeamAddresses[i]].tokens_promised=_amount - 
                                         _walletToEmployee[msg.sender].received_tokens;

        //remove his delegated votes
        delegate_votes(address(this), votes_back_to_contract);

        // ex-employee is not owed anymore tokens
        _walletToEmployee[lockedTeamAddresses[i]].tokens_promised=0;

        //remove employee status
        _walletToEmployee[employeeAddress].employment_status = false;
    }

    /**
     * @dev Delegates the voting power to the
     */
    function delegate_votes(address employee, uint256 amount) internal {
        _wDHN.delegate(employee, amount);
    }
}