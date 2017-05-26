pragma solidity ^0.4.2;

import './AbstractENS.sol';
import './AbstractRegistrar.sol';

contract NameCrowdsourcing {
    enum AuctionStatus {Undefined, PreAuction, Auction, Lost, Won}

    string ensName;
    address beneficiary;
    address[] funderList;
    mapping(address => uint) fundings;
    AbstractENS deployedENS;
    AbstractRegistrar deployedRegistrar;
    AuctionStatus status = AuctionStatus.Undefined;

    function NameCrowdsourcing(string _ensName, address _beneficiary, address ensAddress, address registrarAddress){
        ensName = _ensName;
        beneficiary = _beneficiary;
        deployedENS = AbstractENS(ensAddress);
        deployedRegistrar = AbstractRegistrar(registrarAddress);
    }

    function () payable {

    }
}
