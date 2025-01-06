// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-contracts/contracts/interfaces/IERC20.sol";


contract Lending {
    // === State Variables ====
    IERC20 public token;



    //User Balances and Borrowed amounts: Track ETH deposits, withdrawals, and borrowed amounts.
    mapping(address => uint256) public tokenCollateralBalances;
    mapping(address => uint256) public tokenBorrowedBalances;
    uint256 public totalTokensInContract;

    // === Events ===
    event UserHasDepositedTokens();
    event UserHasWithdrawnTokens();
    event UserHasRepaidTokens();
    event UserHasBorrowedTokens();



    constructor(address _token) {
        token = IERC20(_token);
    }

    // Deposit Function:  Implement a deposit function for users to add ETH.
    function deposit() public payable {
        //check deposit
        require(msg.value > 0, "Please deposit an amount greater than zero.");

        // *** EOA should call approve on the toekn contract to allow lending contract to spend/transfer its tokens ***

        //transfer toekns from msg.sender to contract
        token.transferFrom(msg.sender, address(this), amount);

        //update balances
        tokenCollateralBalances[msg.sender] += amount;
        totalTokensInContract += amount;

        //emit event
        emit UserHasDepositedTokens();
    }

    //Withdraw Function: Add a withdraw function for user to get their ETH.
    function withdraw(uint256 amount) public {
        //check withdraw amount 
        require(amount > 0, "Specify an amount to withdraw");

        //check that user has an existing balance to withdraw
        require(tokenCollateralBalances[msg.sender] >= amount, "You do not have enough tokens deposited to withdraw that amount");

        //update balances
        tokenCollateralBalances[msg.sender] -= amount;
        totalTokensInContract -= amount;

        //transfer tokens to user
        token.transfer(msg.sender, amount);

        //emit event
        emit UserHasWithdrawnTokens();
    }

    //Borrow Function: Create a borrow function for users to take out loans
    function borrow(uint256 amount) public {
        //check borrow amont
        require(amount > 0, "Specify  an amount to borrow");

        //user can only borrow as much as they have deposited as collateral
        require(tokenCollateralBalances[msg.sender] >= amount, "You can't borrow more than you have as collateral.");

        //update balances
        tokenBorrowedBalances[msg.sender] += amount;
        totalTokensInContract -= amount;
        
        //transfer tokens to user
        token.transfer(msg.sender, amount);

        //emit event
        emit UserHasBorrowedTokens();
    }

    //Repay Function: Develop a repay function for users to repay borrowed ETH

    function repay(uint256 amount) public {
        //check repay amount 
        require(msg.value > 0, "Please specify an amount to repay.");

        //check that the user has an outstanding loan
        require(tokenBorrowedBalances[msg.sender] > amount, "You do not have an outstanding loan.");

        // transfer tokens to contract
        token.transferFrom(msg.sender, address(this), amount);

        //update balances
        tokenBorrowedBalances[msg.sender] -= amount;
        totalTokensInContract += amount;

        //emit event
        emit UserHasRepaidTokens();

    }
}
