// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import "./IERC20.sol";
import "./SafeERC20.sol";
import "./ERC721.sol";

import "./ManagerInterface.sol";
contract NFTWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    event Exp(address indexed nftAddress, uint256 indexed tokenId, uint256 exp);
    event Working(address indexed nftAddress, uint256 indexed tokenId, uint256 time);
    struct Hero {
        address nftAddress;
        uint256 tokenId;
        uint256 exp;
        uint256 rank;
        uint256 farmTime;
        uint256 staking;
        uint256 stakingTimeOut;
    }
    mapping(uint256 => Hero) internal heros;
    EnumerableSet.UintSet private tokenSales;
    IERC20 public ganERC20;
    ManagerInterface private manager;
    constructor(
        address _manager,
        address _ganERC20
    ){
        manager = ManagerInterface(_manager);
        ganERC20 = IERC20(_ganERC20);
    }
    modifier onlyOperator() {
        require(manager.isOperator(msg.sender), "require Operator.");
        _;
    }
    modifier validNft(address _nftAddress,uint256 _tokenId){
        require(manager.isNftVisit(_nftAddress),"NFT not accepted");
        _;
    }
    modifier onlyActiveNft(address _nftAddress,uint256 _tokenId){
        require(manager.isNftVisit(_nftAddress),"NFT not accepted");
        uint256 vId = getVId(_nftAddress,_tokenId);
        Hero storage hero = heros[vId];
        require(hero.staking >0,"not staking");
        _;
    }
    function staking(address _nftAddress,uint256 _tokenId) validNft(_nftAddress,_tokenId) public  {
        uint256 vId = getVId(_nftAddress,_tokenId);
        Hero storage hero = heros[vId];
        require(hero.staking == 0,"have been staking");
        hero.nftAddress = _nftAddress;
        hero.tokenId = _tokenId;
        if(hero.rank==0){
            hero.rank = 1;
        }
        uint256 stakingAmount = manager.nftStakingAmount();
        ganERC20.transferFrom(msg.sender,address(this), stakingAmount);
        hero.staking = stakingAmount;
    }
    function stakingTimeOutBegin(address _nftAddress,uint256 _tokenId) external onlyOperator{
        uint256 vId = getVId(_nftAddress,_tokenId);
        Hero storage hero = heros[vId];
        hero.stakingTimeOut = block.timestamp + 86400;
    }
    function unstake(address _nftAddress,uint256 _tokenId) public onlyActiveNft(_nftAddress,_tokenId){
        require(ERC721(_nftAddress).ownerOf(_tokenId) == msg.sender, "not own");
        uint256 vId = getVId(_nftAddress,_tokenId);
        Hero storage hero = heros[vId];
        require(hero.stakingTimeOut>0 && hero.stakingTimeOut<block.timestamp,"it's not time to unstake");
        hero.staking = 0;
        hero.stakingTimeOut = 0;
    }
    function working(address _nftAddress, uint256 _tokenId, uint256 _time) public onlyOperator {
        uint256 vId = getVId(_nftAddress,_tokenId);
        require(_time > 0, "no time");
        Hero storage hero = heros[vId];
        hero.farmTime = hero.farmTime.add(_time);
        emit Working(_nftAddress, _tokenId, _time);
    }

    function exp(address _nftAddress, uint256 _tokenId, uint256 _exp) public  onlyOperator {
        require(_exp > 0, "no exp");
        uint256 vId = getVId(_nftAddress,_tokenId);
        Hero storage hero = heros[vId];
        require(hero.staking >0,"hero not staking" );
        hero.exp = hero.exp.add(_exp);
        emit Exp(_nftAddress, _tokenId, _exp);
    }
    function getVId(address _nftAddress,uint256 _tokenId) private pure returns(uint256){
        return uint256(uint160(_nftAddress)).add(_tokenId);
    }
    function getHero(address _nftAddress, uint256 _tokenId)
        public
        view
        returns (Hero memory)
    {
        uint256 vId = getVId(_nftAddress,_tokenId);
        return heros[vId];
    }

    function heroLevel(address _nftAddress,uint256 _tokenId) public view returns (uint256) {
        return getLevel(getHero(_nftAddress,_tokenId).exp);
    }
    function upgrade(address _nftAddress, uint256 _tokenId) public onlyOperator{
        uint256 vId = getVId(_nftAddress,_tokenId);
        Hero storage hero = heros[vId];
        require(hero.staking >0,"hero not staking" );
        hero.rank = hero.rank + 1; 
    }
    function getRare(address _nftAddress, uint256 _tokenId) public view returns (uint256) {
        return getHero(_nftAddress, _tokenId).rank;
    }

    function getLevel(uint256 _exp) internal pure returns (uint256) {
        if (_exp < 100) {
            return 1;
        } else if (_exp < 300) {
            return 2;
        } else if (_exp < 600) {
            return 3;
        } else if (_exp < 1200) {
            return 4;
        } else if (_exp < 2500) {
            return 5;
        } else {
            return 6;
        }
    }
}