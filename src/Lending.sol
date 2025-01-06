// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract Lending {

    //User Balances and Borrowed amounts: Track ETH deposits, withdrawals, and borrowed amounts.
    // === State Variables ====
    mapping(address => uint256) public balances;
    mapping(address => uint256) public borrowed;
    uint256 public totalEthInContract;

    // === Events ===
    event UserHasDepositedEth();
    event UserHasWithdrawnEth();
    event UserHasRepaidEth();
    event UserHasBorrowedEth();

    // Deposit Function:  Implement a deposit function for users to add ETH.
    function deposit() public payable {
        //check deposit
        require(msg.value > 0, "No Ether Transferred");

        //update balances
        balances[msg.sender] += msg.value;
        totalEthInContract += msg.value;

        //emit event
        emit UserHasDepositedEth();
    }

    //Withdraw Function: Add a withdraw function for user to get their ETH.
    function withdraw(uint256 amount) public {
        //check withdraw amount 
        require(amount > 0, "Specify an amount to withdraw");
        require(balances[msg.sender] >= amount, "You cannot withdraw more than you have deposited");

        //update balances
        totalEthInContract -= amount;
        balances[msg.sender] -= amount;

        //send eth to user
        payable(msg.sender).transfer(amount);

        //emit event
        emit UserHasWithdrawnEth();
    }

    //Borrow Function: Create a borrow function for users to take out loans
    function borrow(uint256 amount) public {
        //check borrow amont
        require(amount > 0, "Specify  an amount to borrow");
        require(amount < totalEthInContract, "Not Enough Eth in Contract to borrow");

        //update balances
        borrowed[msg.sender] += amount;
        totalEthInContract -= amount;
        
        //send eth to user
        payable(msg.sender).transfer(amount);

        //emit event
        emit UserHasBorrowedEth();
    }

    //Repay Function: Develop a repay function for users to repay borrowed ETH

    function repay() public payable {
        //check repay amount 
        require(msg.value > 0, "No ethet sent to repay");

        //update balances
        borrowed[msg.sender] -= msg.value;
        totalEthInContract += msg.value;

        //emit event
        emit UserHasRepaidEth();

    }
}
