# Basics
## Locked Team
- List of addresses (employees) and corresponding DHN token amounts they will receive;
- Tokens  are locked and not ditributed for 3 years;
- After the 3 years, the addresses will receive 1/60 of their corresponding tokens each month for the next 5 years (5*12 months = 60);
- The addresses should be able to cast a vote in the DAO with the weight of the locked tokens;********** *WRITE OPTIONS* **********

## New Employess
- Besides the amounts established fot the **Locked Team**, there is also a **Leftover** amount of tokens. 
- These tokens are to be used to award to new Dohrnii emploees;
- The split of the **Leftover** tokens can vary from employee to emploee, so it should be changeable;

## Leaving Employess
- If an employee leaves, he should be able to get the tokens corresponding to the time he gave to the Dohrnii organization;
- The tokens that the quitting employee will not receive, are added on to the **Leftover** amount;

## Changes in the Smart Contract
- The changes should only be done in a multi-sig way; ********** *TO DO* **********
- Only the status of an employee (currently working or not currently working) and the split of the **Leftover** amount, should be editable;

# Code
## Variables
- Each employee should have its struct: {Name(string), Tokens_to_receive(uint), Received_Tokens(uint), Employment_Status(bool)}
- Array of employee structs
- Mapping from employee name to employee struct
## Functions
- Constructor will have all the addresses and amounts of the initial. This will call the set_payment function;
- set_payment(string name, uint Tokens_to_receive):
- retrieve_payment()
- new_employee()
- quitting_employee()
- change_employee_split ???

