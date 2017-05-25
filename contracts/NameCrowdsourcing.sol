pragma solidity ^0.4.2;

import './AbstractENS.sol';
import './AbstractRegistrar.sol';

contract NameCrowdsourcing {
    string ensName;
    address beneficiary;
    address[] funderList;
    mapping(address => uint) fundings;
    
}
