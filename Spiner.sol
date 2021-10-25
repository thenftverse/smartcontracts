// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import "./GalacticArenaNFT.sol";
import "./Ownable.sol";
import "./NFTWrapper.sol";

interface IGalacticArenaERC20 is IERC20 {
    function win(address winner, uint256 reward) external;
}

contract Spiner is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    enum SPIN_RESULT {
        SLOT_1,
        SLOT_2,
        SLOT_3,
        SLOT_4, 
        SLOT_5,
        SLOT_6,
        SLOT_7
    }
    event SpinEvent(
        address indexed _nftAddress,
        uint256 indexed _tokenId,
        SPIN_RESULT result,
        address user
    );
    event FlipCardEvent(
        address indexed _nftAddress,
        uint256 indexed _tokenId,
        uint256 result,
        address user
    );
    // The GalacticArenaNFT TOKEN!
    IGalacticArenaERC20 public ganToken;
    GalacticArenaNFT public ganNFT;
    ManagerInterface public manager;
    NFTWrapper public visitNFT;
    mapping(uint256 => uint256) public freeSpin;
    mapping(uint256 => uint256) public paidSpin; //lượt quay đã mua
    mapping(uint256 => uint256) public freeSpinTimeOut;
    mapping(uint256 => uint256) public flipCards;
    constructor(
        address _manager,
        IGalacticArenaERC20 _ganToken,
        GalacticArenaNFT _ganNFT,
        NFTWrapper _wrapperNFT
    ) {
        ganToken = _ganToken;
        ganNFT = _ganNFT;
        visitNFT = _wrapperNFT;
        manager = ManagerInterface(_manager);
    }

    modifier validSessionSpin(address _nftAddress, uint256 _tokenId) {
        uint256 vId = getVId(_nftAddress, _tokenId);
        require(paidSpin[vId]>0 || block.timestamp>freeSpinTimeOut[vId],"it's not time to spin");
        if(_nftAddress!=address(ganNFT)){
            require(visitNFT.getHero(_nftAddress,_tokenId).staking > 0,"visit NFT not staking");
        }
        _;
    }
    function buyExtraSpin(address _nftAddress, uint256 _tokenId,uint256 _amount) public{
        require(ERC721(_nftAddress).ownerOf(_tokenId) == _msgSender(), "not own");
        require(_amount>0,"amount >0");
        uint256 vId = getVId(_nftAddress, _tokenId);
        uint256 rank = getRank(_nftAddress,_tokenId);
        uint256 level = getLevel(_nftAddress,_tokenId);
        uint256 price = 150+(rank-1)*75+(level-1)*(rank+1)*15;
        ganToken.transferFrom(_msgSender(),manager.feeAddress(),price.mul(_amount).mul(10**18));
        paidSpin[vId] = paidSpin[vId].add(1);
    }
    function getVId(address _nftAddress,uint256 _tokenId) private pure returns(uint256){
        return uint256(uint160(_nftAddress)).add(_tokenId);
    }
    function spinTimes(address _nftAddress, uint256 _tokenId) public view returns (uint256) {
        uint256 vId = getVId(_nftAddress, _tokenId);
        return freeSpin[vId];
    }
    function setManager(address _config) public onlyOwner {
        manager = ManagerInterface(_config);
    }

    function setNFT(address _ganNFT) public onlyOwner {
        ganNFT = GalacticArenaNFT(_ganNFT);
    }

    function setERC20(address _ganERC20) public onlyOwner {
        ganToken = IGalacticArenaERC20(_ganERC20);
    }
    function getPaidSpin(address _nftAddress,uint256 _tokenId) public view returns(uint256){
          uint256 vId = getVId(_nftAddress, _tokenId);
          return paidSpin[vId];
    }
    function getFlipCard(address _nftAddress,uint256 _tokenId) public view returns(uint256){
          uint256 vId = getVId(_nftAddress, _tokenId);
          return flipCards[vId];
    }
     function getfreeSpinTimeOut(address _nftAddress,uint256 _tokenId) public view returns(uint256){
          uint256 vId = getVId(_nftAddress, _tokenId);
          return freeSpinTimeOut[vId];
    }
    function getMaxSpinPerDay(uint256 _rank) private pure returns(uint256){
        return _rank+3;
    }
    function spin(address _nftAddress, uint256 _tokenId)
        external
        validSessionSpin(_nftAddress, _tokenId)
    {
        require(_msgSender() == tx.origin,"Do not try to cheat");
        require(ERC721(_nftAddress).ownerOf(_tokenId) == _msgSender(), "not own");
        uint256 vId = getVId(_nftAddress, _tokenId);
        SPIN_RESULT result = getResult(vId);
        processRewardExpAndToken(_nftAddress, _tokenId, result);
        //
        if(result==SPIN_RESULT.SLOT_7){
            flipCards[vId] = flipCards[vId].add(1);
        }
        updateStateSpin(_nftAddress, _tokenId);
        emit SpinEvent(_nftAddress,_tokenId, result, _msgSender());
    }
    function flipCard(address _nftAddress, uint256 _tokenId) public {
        require(_msgSender() == tx.origin,"Do not try to cheat");
        require(ERC721(_nftAddress).ownerOf(_tokenId) == _msgSender(), "not own");
        uint256 vId = getVId(_nftAddress, _tokenId);
        require(flipCards[vId]>0,"no card");
        uint256 result=0;
        //
        uint256 rnd = random(vId, 4).div(100);
        uint256 trible = rnd % 6;
        if(rnd<20){
            result=1;
            ganNFT.mintHero(_msgSender(),GalacticArenaNFT.Tribe(trible) , 10**30);
        }
        else if(rnd<40){
            result=2;
            ganNFT.layEgg(1,_msgSender(),GalacticArenaNFT.Tribe(trible));
        }
        else if(rnd<60){
            result=3;
            if(_nftAddress==address(ganNFT)){
                ganNFT.exp(_tokenId, 300);
            }
            else
            {
                visitNFT.exp(_nftAddress,_tokenId, 300);
            }
        }
        else if(rnd<80){
            result=4;
            if(_nftAddress==address(ganNFT)){
                ganNFT.upgrade(_tokenId);
            }
            else
            {
                visitNFT.upgrade(_nftAddress,_tokenId);
            }
        }
        else{
            result=5;
            paidSpin[vId] = paidSpin[vId].add(1);
        }
        //
        flipCards[vId] = flipCards[vId].sub(1);
        emit FlipCardEvent(_nftAddress,_tokenId, result, _msgSender());
    }
    function processRewardExpAndToken(address _nftAddress, uint256 _tokenId,SPIN_RESULT result) private{
        uint256 level = getLevel(_nftAddress, _tokenId);
        uint256 rank = getRank(_nftAddress, _tokenId);
        //
        uint256 exp = getExp(result, level, rank);
        uint256 tokenReward = getReward(result, level, rank);
        if(exp>0){
            if(_nftAddress==address(ganNFT)){
                ganNFT.exp(_tokenId, exp);
            }
            else
            {
                visitNFT.exp(_nftAddress,_tokenId, exp);
            }
            ganToken.win(_msgSender(), tokenReward * 10**18);
        }
    }
    function updateStateSpin(address _nftAddress, uint256 _tokenId) private {
        uint256 vId = getVId(_nftAddress, _tokenId);
        uint256 rank = getRank(_nftAddress, _tokenId);
        if(paidSpin[vId]>0){
            paidSpin[vId] = paidSpin[vId].sub(1); 
        }
        else{
            freeSpin[vId] = freeSpin[vId].add(1);
            if(freeSpin[vId]==getMaxSpinPerDay(rank)){
                freeSpin[vId]=0;
                freeSpinTimeOut[vId] = block.timestamp + 86400;
                visitNFT.stakingTimeOutBegin(_nftAddress,_tokenId);
            } 
        }
    }
    function getResult(uint256 _tokenId) internal view returns(SPIN_RESULT) {
        uint256 rnd = random(_tokenId, 4).div(100);
        if(rnd<24){
             return SPIN_RESULT.SLOT_1;
         }
        else if(rnd<41){
             return SPIN_RESULT.SLOT_2;
         }
        else if(rnd<52){
             return SPIN_RESULT.SLOT_3;
         }
        else if(rnd<62){
             return SPIN_RESULT.SLOT_4;
         }
        else if(rnd<67){
             return SPIN_RESULT.SLOT_5;
         }
        else if(rnd<97){
             return SPIN_RESULT.SLOT_6;
         }
        else{
             return SPIN_RESULT.SLOT_7;
         }
    }
    function getExp(SPIN_RESULT _result,uint256 _level, uint256 _rare) internal pure returns(uint256){
        uint256 x= getMultiplier(_level,_rare);
        if(_result==SPIN_RESULT.SLOT_1){
            return 3*x/10;
        }
        else if(_result==SPIN_RESULT.SLOT_2){
            return 5*x/10;
        }
        else if(_result==SPIN_RESULT.SLOT_3){
            return 10*x/10;
        }
        else if(_result==SPIN_RESULT.SLOT_4){
            return 20*x/10;
        }
        else if(_result==SPIN_RESULT.SLOT_5){
            return 40*x/10;
        }
        else {
            return 0;
        }
        
    }
    
    function getReward(SPIN_RESULT _result,uint256 _level, uint256 _rare) internal pure returns(uint256){
        uint256 x= getMultiplier(_level,_rare);
        if(_result==SPIN_RESULT.SLOT_1){
            return 60*x/10;
        }
        else if(_result==SPIN_RESULT.SLOT_2){
            return 120*x/10;
        }
        else if(_result==SPIN_RESULT.SLOT_3){
            return 300*x/10;
        }
        else if(_result==SPIN_RESULT.SLOT_4){
            return 450*x/10;
        }
        else if(_result==SPIN_RESULT.SLOT_5){
            return 600*x/10;
        }
        else {
            return 0;
        }
    }
    function getMultiplier(uint256 _level, uint256 _rare) pure internal returns(uint256) {
         return 10+ (_rare-1)*5 + (_level-1)*(_rare+1);
    }

    function random(uint256 _id, uint256 _length)
        private
        view
        returns (uint256)
    {
        return
            uint256(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            blockhash(block.number-1),
                            block.timestamp,
                            gasleft(),
                            _id
                        )
                    )
                )
            ) % (10**_length);
    }
    function getLevel(address _nftAddress,uint256 _tokenId) private view returns(uint256){
        if(_nftAddress==address(ganNFT)){
            return ganNFT.heroLevel(_tokenId);
        }
        else{
            return visitNFT.heroLevel(_nftAddress,_tokenId);
        }
    }
    function getRank(address _nftAddress,uint256 _tokenId) private view returns(uint256){
        if(_nftAddress==address(ganNFT)){
            return ganNFT.getRare(_tokenId);
        }
        else{
            return visitNFT.getRare(_nftAddress,_tokenId);
        }
    }
}