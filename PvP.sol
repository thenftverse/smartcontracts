// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.4.0 <0.9.0;
pragma abicoder v2;

import "./Initializable.sol";
import "./AccessControlUpgradeable.sol";
import "./ERC721Upgradeable.sol";
import "./OwnableUpgradeable.sol";
import "./EnumerableSet.sol";
import "./EnumerableMap.sol";
import "./IERC20.sol";
import "./GalacticArenaNFT.sol";
import "./SafeERC20.sol";
import "./ManagerInterface.sol";
import "./IRef.sol";
import "./NFTWrapper.sol";
contract PVP is 
    Initializable,
    AccessControlUpgradeable,
    OwnableUpgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    event CreateMatch(uint256 indexed tokenId, address owner, uint256 amount);
    event CancelMatch(uint256 indexed tokenId, address owner);
    event UpdateAmount(
        uint256 indexed tokenId,
        address owner,
        uint256 newAmount
    );
    event Fight1(address indexed nftAddress1, uint256 indexed tokenId1, address owner1,address nftAddress2,uint256 tokenId2, address owner2,uint256 indexed result,uint256 reward, address currency);
    event Fight2(address nftAddress1, uint256 tokenId1, address owner1,address indexed nftAddress2,uint256 indexed tokenId2, address owner2,uint256  result,uint256 reward, address currency);

    struct ItemMatch {
        uint256 tokenId;
        address owner;
        uint256 amount;
        uint256 createBlockTime;
        address nftAddress;
        address currency;
    }
   
    mapping(uint256 => ItemMatch) internal arena;
    EnumerableSet.UintSet private tokensInArena;
    mapping(address => EnumerableSet.UintSet) private fighterTokens;
    mapping(address => bool) private userBlacklist;
    mapping(uint256 => bool) private nftIdBlacklist;
    
    ManagerInterface public manager;
    IERC20 public ganERC20;
    GalacticArenaNFT public ganNFT;
    NFTWrapper public visitNFT;
    bytes32 public constant PVP_ADMIN = keccak256("PVP_ADMIN");

    function initialize(
        address _manager,
        address _ganERC20,
        address _ganNFT,
        address _wrapperNFT
    ) public initializer {
        __AccessControl_init_unchained();
        __Ownable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PVP_ADMIN, msg.sender);

        manager = ManagerInterface(_manager);
        ganERC20 = IERC20(_ganERC20);
        ganNFT = GalacticArenaNFT(_ganNFT);
        visitNFT = NFTWrapper(_wrapperNFT);
    }

    function setUserBlacklist(address user, bool value) public onlyOwner {
        userBlacklist[user] = value;
    }

    function setNftIdBlacklist(address _nftAddress, uint256 _tokenId, bool _value) public onlyOwner {
         uint256 vId = getVId(_nftAddress, _tokenId);
        nftIdBlacklist[vId] = _value;
    }
    function getVId(address _nftAddress,uint256 _tokenId) private pure returns(uint256){
        return uint256(
                    keccak256(
                        abi.encodePacked(
                            _nftAddress,
                            _tokenId
                        )
                    )
                );
    }
    function createMatch(uint256 _tokenId,address _nftAddress, uint256 _amount,address _currency) payable public {
        require(tx.origin==_msgSender(),"don't try to cheat");
        if(_currency==address(0x0)){
            require(msg.value>=_amount,"not enough money");
        }
        else{
            IERC20(_currency).transferFrom(_msgSender(), address(this), _amount);
        }
        require(_nftAddress==address(ganNFT) || manager.isNftVisit(_nftAddress),"NFT not accepted");
        require(ERC721(_nftAddress).ownerOf(_tokenId) == _msgSender(), "not own");
        require(_amount > 0, "price > 0 ");
        if(_nftAddress!=address(ganNFT)){
            require(ganERC20.balanceOf(_msgSender())>=manager.minBalanceToPvP(),"owner not enough token to PvP");
        }
        uint256 vId = getVId(_nftAddress, _tokenId);
        ItemMatch storage tokenInMatch = arena[vId];
        require(tokenInMatch.tokenId == 0, "Match with token exists");
        require(userBlacklist[_msgSender()] == false, "user blacklisted");
        require(nftIdBlacklist[vId] == false, "nft blacklisted");
        require(!tokensInArena.contains(vId),"nft already in the arena");
        require(!fighterTokens[_msgSender()].contains(vId),"nft already in the arena 2");
        tokensInArena.add(vId);
        fighterTokens[_msgSender()].add(vId);
        // ERC721(_nftAddress).transferFrom(_msgSender(),address(this), _tokenId);
        arena[vId] = ItemMatch({
                tokenId: _tokenId,
                owner: _msgSender(),
                amount:_amount,
                createBlockTime: block.timestamp,
                nftAddress: _nftAddress,
                currency: _currency
            });
        emit CreateMatch(_tokenId, _msgSender(), _amount);
    }
    function cancelMatch(uint256 _tokenId,address _nftAddress) public {
        require(tx.origin==msg.sender,"don't try to cheat");
        uint256 vId = getVId(_nftAddress, _tokenId);
        ItemMatch storage itemMatch = arena[vId];
        require(itemMatch.owner == _msgSender(), "not own");
        
        if(itemMatch.currency==address(0)){
            payable(itemMatch.owner).transfer(itemMatch.amount);
        }
        else{
            IERC20(itemMatch.currency).transfer(itemMatch.owner, itemMatch.amount);
        }
        removeMatch(itemMatch.owner, _nftAddress, _tokenId);
        emit CancelMatch(_tokenId, _msgSender());
    }

    function updateAmount(uint256 _tokenId,address _nftAddress, uint256 _amount) public {
        require(_amount > 0, "amount > 0");
        uint256 vId = getVId(_nftAddress, _tokenId);
        require(tokensInArena.contains(vId), "nft is not in arena");
        ItemMatch storage itemMatch = arena[vId];
        require(itemMatch.owner == _msgSender(), "not own");
        // require(_amount != itemMatch.amount,"do not waste gas");
        uint256 difference = 0;
        address beneficiary = address(this);
        if(_amount<itemMatch.amount){
            difference = itemMatch.amount.sub(_amount);
            beneficiary = itemMatch.owner;
        }
        else{
            difference = _amount.sub(itemMatch.amount);
            beneficiary = address(this);
        }
        if(itemMatch.currency==address(0)){
                payable(itemMatch.owner).transfer(itemMatch.amount);
        }
        else{
                IERC20(itemMatch.currency).transfer(itemMatch.owner, itemMatch.amount);
            }
        itemMatch.amount = _amount;
    }
    
    function getFightFeeRate(uint256 _tokenId,address _nftAddress) private view returns(uint256) {
        if(_nftAddress==address(ganNFT)){
            uint256 rank = ganNFT.getRare(_tokenId);
            return 55-rank*5;
        }
        else{
            uint256 rank = visitNFT.getRare(_nftAddress,_tokenId);
            return 75-rank*5;
        }
    }
    
    function fight(uint256 _tokenId,address _nftAddress,uint256 _ownTokenId,address _ownNftAddress) public payable {
        require(tx.origin==_msgSender(),"don't try to cheat");
        require(_ownNftAddress==address(ganNFT) || manager.isNftVisit(_ownNftAddress),"NFT not accepted");
        require(ERC721(_ownNftAddress).ownerOf(_ownTokenId) == _msgSender(), "not own");
         if(_ownNftAddress!=address(ganNFT)){
            require(ganERC20.balanceOf(_msgSender())>=manager.minBalanceToPvP(),"owner not enough token to PvP");
        }
        uint256 vId = getVId(_nftAddress, _tokenId);
        require(tokensInArena.contains(vId), "not in Arena");
        ItemMatch storage itemMatch = arena[vId];
        //
        uint256 bonusWinRate1 =  (getLevel(_nftAddress,_tokenId)-1)*2 + (getRank(_nftAddress,_tokenId)-1)*3;
        uint256 bonusWinRate2 =  (getLevel(_ownNftAddress,_ownTokenId)-1)*2 + (getRank(_ownNftAddress,_ownTokenId)-1)*3;
        uint256 finalWinRate1 = 50 + bonusWinRate1 - bonusWinRate2;
        uint256 finalWinRate2 = 50 + bonusWinRate2 - bonusWinRate1;
        //
        uint256 amountBet2 = itemMatch.amount.mul(finalWinRate2).div(finalWinRate1);
        uint256 reward = itemMatch.amount + amountBet2;
        if(itemMatch.currency==address(0)){
            require(msg.value>=amountBet2,"msg.value not enough");
        }
        else{
            IERC20(itemMatch.currency).transferFrom(_msgSender(), address(this), amountBet2);
        }
        //
        processReward(_tokenId,_nftAddress,_ownTokenId,_ownNftAddress,finalWinRate1,amountBet2,reward,itemMatch);
        //
        removeMatch(itemMatch.owner, _nftAddress,_tokenId);
        //
    }
    
    function processReward(uint256 _tokenId,address _nftAddress,uint256 _ownTokenId,address _ownNftAddress,uint256 finalWinRate1, uint256 amountBet2, uint256 reward,ItemMatch storage itemMatch ) internal {
        uint256 rnd = random(_tokenId, 4).div(100);
        if(rnd<finalWinRate1){ //Challenger win
            uint256 fightFeeRate = getFightFeeRate(_tokenId, _nftAddress);
            uint256 fee = amountBet2.mul(fightFeeRate).div(1000);
            uint256 netReward = reward.sub(fee);
            finallyMatch(itemMatch, itemMatch.owner, netReward, fee);
            //
            emit Fight1(_nftAddress, _tokenId, itemMatch.owner,_ownNftAddress,_ownTokenId, _msgSender(),1,netReward, itemMatch.currency);
            emit Fight2(_nftAddress, _tokenId, itemMatch.owner,_ownNftAddress,_ownTokenId, _msgSender(),1,netReward, itemMatch.currency);
        }
        else//Fighter win
        {
            uint256 fightFeeRate = getFightFeeRate(_ownTokenId, _ownNftAddress);   
            uint256 fee = itemMatch.amount.mul(fightFeeRate).div(1000);
            uint256 netReward = reward.sub(fee);
            finallyMatch(itemMatch, _msgSender(), netReward, fee);
            //
            emit Fight1(_nftAddress, _tokenId, itemMatch.owner,_ownNftAddress,_ownTokenId, _msgSender(),2,netReward, itemMatch.currency);
            emit Fight2(_nftAddress, _tokenId, itemMatch.owner,_ownNftAddress,_ownTokenId, _msgSender(),2,netReward, itemMatch.currency);
        }
    }
    function finallyMatch(ItemMatch storage itemMatch,address winner,uint256 netReward,uint256 fee) internal{
        if(itemMatch.currency==address(0)){
            payable(itemMatch.owner).transfer(netReward);
            payable(manager.feeAddress()).transfer(fee);
        }
        else{
            IERC20(itemMatch.currency).transfer(winner, netReward);
            IERC20(itemMatch.currency).transfer(manager.feeAddress(), fee);
        }
    }
    function removeMatch(address _owner, address _nftAddress,uint256 _tokenId) internal{
        uint256 vId = getVId(_nftAddress, _tokenId);
        // ItemMatch storage itemMatch = arena[vId];
        // ERC721(_nftAddress).transferFrom(address(this),itemMatch.owner, _tokenId);
        tokensInArena.remove(vId);
        fighterTokens[_owner].remove(vId);
        arena[vId] = ItemMatch({
            tokenId: 0,
            owner: address(0),
            amount: 0,
            createBlockTime: 0,
            nftAddress: address(0),
            currency: address(0)
        });
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
   
    function arenaSize() public view returns (uint256) {
        return tokensInArena.length();
    }
    function tokensInArenaByIndex(uint256 index) public view returns (ItemMatch memory) {
        uint256 vId = tokensInArena.at(index);
        return arena[vId];
    }
    function tokenByOwner(address _owner) public view returns(uint256){
        return fighterTokens[_owner].length();
    }
    function tokensInArenaOfOwnerByIndex(address _fighter, uint256 index)
        public
        view
        returns (ItemMatch memory)
    {
        uint256 vId = fighterTokens[_fighter].at(index);
        return arena[vId];
    }
    function tokenInArena(uint256 _tokenId,address _nftAddress) public view returns(bool){
        uint256 vId = getVId(_nftAddress, _tokenId);
        return tokensInArena.contains(vId);
    }
    function getMatch(address _nftAddress, uint256 _tokenId) public view returns (ItemMatch memory) {
        uint256 vId = getVId(_nftAddress, _tokenId);
        return arena[vId];
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

}
