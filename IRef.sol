pragma solidity >=0.6.0 <0.9.0;
interface IRef {
    function getReferences(address account) external view returns(address);
}