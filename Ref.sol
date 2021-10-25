pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import "./Ownable.sol";

contract Ref is Ownable {
    mapping(address=>address) public references;
    constructor(){

    }
    function register(address ref) public{
        require(references[msg.sender]==address(0),"This account has been linked");
        references[msg.sender] = ref;
    }
    function getReferences(address account) public view returns(address){
        return references[account];
    }
    function removeReferences(address account) public onlyOwner{
        delete references[account];
    }
}