// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "forge-std/console2.sol";


contract Lending {
    // === State Variables ====
    IERC20 public token;



    //User Balances and Borrowed amounts: Track ETH deposits, withdrawals, and borrowed amounts.
    mapping(address => uint256) public tokenCollateralBalances;
    mapping(address => uint256) public tokenBorrowedBalances;
    mapping(address => uint256) public ethCollateralBalances;
    uint256 public totalTokensInContract;
    uint256 public MIN_HEALTH_FACTOR = 1e15;

    // === Events ===
    event UserHasDepositedTokens();
    event UserHasWithdrawnTokens();
    event UserHasRepaidTokens();
    event UserHasBorrowedTokens();



    constructor(address _token) {
        token = IERC20(_token);
    }

    // === DEPOSIT : deposit ERC20 tokens (that can then be borrowed by borrowers)
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

    // === WITHDRAW : withdraw ERC20 tokens
    function withdraw(uint256 amount) public {
        //check withdraw amount 
        require(amount > 0, "Specify an amount to withdraw");

        //check that user has an existing balance to withdraw
        require(tokenCollateralBalances[msg.sender] >= amount, "You do not have enough tokens deposited to withdraw that amount");

        require(amount < totalTokensInContract, "There are currently not enough tokens in the contract to withdraw.");

        //update balances
        tokenCollateralBalances[msg.sender] -= amount;
        totalTokensInContract -= amount;

        //transfer tokens to user
        token.transfer(msg.sender, amount);

        //emit event
        emit UserHasWithdrawnTokens();
    }

    //Borrow Function: Create a borrow function for users to take out loans
    function borrowTokensWithCollateral(uint256 amount) public  payable{
        //check borrow amont
        require(amount > 0, "Specify  an amount to borrow");

        // calculate the max tokens they can borrow based on the ETH transferred into the contract
        uint256 amountEthCollateralInWei = msg.value;   // will be in WEI, so 5 ETH = 5 000 000 000 000 000 000 WEI
        uint256 maxTokenBorrowAmount = _calculateMaxTokenBorrorAmount(amountEthCollateralInWei);

        // can't borrow more than the max
        require(amount < maxTokenBorrowAmount, "Borrow amount requested too high.");

        // update eth balances
        ethCollateralBalances[msg.sender]  += msg.value;


        //update token balances
        tokenBorrowedBalances[msg.sender] += amount;
        totalTokensInContract -= amount;
        
        //transfer tokens to user
        token.transfer(msg.sender, amount);

        //emit event
        emit UserHasBorrowedTokens();
    }

    function _calculateMaxTokenBorrorAmount(uint256 amountEthCollateralInWei) internal returns (uint256) {
        //amountinEth = 5000000000000000000 / 1e18 = 5

        uint256 amountInEth = amountEthCollateralInWei / 1e18;

        //maxTokenBorrowAmount = 5 * 1000 = 5000
        uint256 maxTokenBorrowAmount = amountInEth * 1000;

        //@NOTICE: RATIO OF TOKENS TO ETH. IN THE REAL WORLD WOULD BE DYNAMIC
        //@NOTICE: IN ORDER TO CALCULATE THE AMOUNT OF OUR TOKEN PER ETH WE'D NEED TO CALL AN ORAVLE
        return maxTokenBorrowAmount;
    }

    //Repay Function: Develop a repay function for users to repay borrowed ETH
    function repay(uint256 amount) public {
        //check amount is greater than zero 
        require(msg.value > 0, "Please specify an amount to repay.");

        //check that the user has an outstanding loan
        require(tokenBorrowedBalances[msg.sender] > amount, "You do not have an outstanding loan.");

        //@NOTICE: AS WITH DEPOSITING TOKENS..
        //... THE EOA SHOULD CALL APPROVE ON THE TOKEN CONTRACT TO ALLOW LENDING CONTRACT TO SPEND/TRANSFER IT'S TOKENS.

        // transfer tokens to contract
        token.transferFrom(msg.sender, address(this), amount);

        //update balances
        tokenBorrowedBalances[msg.sender] -= amount;
        totalTokensInContract += amount;

        //calculate amount of ETH to transfer back to borrower based on the tokens repaid...
        // 1111 * 1e18 = 1111000000000000000000 (aka 1111e18)
        uint256 ethToRefund = (amountToRepay * 1e18) / 1000;

        //transfer ETH collateral back to borrower
        payable(msg.sender).transfer(ethToRefund); 

        //emit event
        emit UserHasRepaidTokens();

    }

    function nukeHealthFactor(address borrower) external {
        // add 987000 tokens to the borrower's borrowed amount
        tokenBorrowedBalances[borrower] += 987000;
    }

    function liquidate(address borrower, uint256 tokenAmountToRepay) external payable {
        // check that the borrower has a bad LTV ratio (i.e. tokens borrowed exceed acceptable levels compared ot ETH collaterla deposited)
        // tokenBorrowedBalances[borrower] - will be in standard magnitude, eg. 5000
        uint256 tokensCurrentlyBorrowed = tokenBorrowedBalances[borrower];

        require(
            tokenAmountToRepay <= tokensCurrentlyBorrowed,
            "You are trying to repay beyond what was issued for the loan you are trying to liquidate."
        );

        //ethCollateralBalances[borrower] - will be in WEI, so 5 ETH
        uint256 ethCollateralInWei = ethCollateralBalances[borrower];
        // Ok! e.g.  borrowerHealthFactor = 5000000000000000000 / 5000 (1000000000000000, exactly the same as MIN_HEALTH_FACTOR)
        // Ok! e.g.  borrowerHealthFactor = 5000000000000000000 / 4000 (1250000000000000, 25% above IN_HEALTH_FACTOR)
        // LIQUIDATABLE! e.g.  borrowerHealthFactor = 5000000000000000000 / 6000 (833333333333333, 16.6% UNDER MIN_HEALTH_FACTOR)
        uint256 borrowerHealthFactor = ethCollateralInWei / tokensCurrentlyBorrowed;

        require(borrowerHealthFactor < MIN_HEALTH_FACTOR, "User loan is not liquidateable.");

        //transfer tokens from liquidator into the contract
        token.transfer(msg.sender, tokenAmountToRepay);

        //update token balances of borrower - i.e loan repaid to a certain level (liquidator has paid off some of their loan)
        tokenBorrowedBalances[borrower] -= tokenAmountToRepay;

        //calculate amount of ETH to send to the liquidator - i.e the value (in ETH) of the token they've repaid
        // uint256 onEth = 1e18;
        uint256 tokensPerEth = 1000; // this line is essentially our "oracle" for this part.
        uint256 ethAmount = tokenAmountToRepay / tokensPerEth;
        uint256 ethAmountInWei = ethAmount * 1e18;

        //calculate their BONUS (10%) in ETH that they will get fo liquidating the user and maintaining the health of the protocol
        uint256 bonus = ethAmountInWei / 10;
        uint256 totalEthToLiquidator = ethAmountInWei * bonus;

        //transfer ETH to liquidator
        payable(msg.sender).transfer(totalEthToLiquidator);

    }
}
