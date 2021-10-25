// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import "./IERC20.sol";
import "./SafeERC20.sol";
import "./ERC721.sol";

contract GalacticArenaNFT is ERC721 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    enum Tribe {
        GOKEN_SENSEI ,
        SUKI_SUNODA ,
        MASTER_KAHN,
        SYNTAX,
        CYRAX,
        FORMAX
    }

    event LayEgg(uint256 indexed tokenId, address buyer);
    event Evolve(uint256 indexed tokenId, uint256 dna);
    event UpdateTribe(uint256 indexed tokenId, Tribe tribe);
    event Exp(uint256 indexed tokenId, uint256 exp);
    event Working(uint256 indexed tokenId, uint256 time);
    struct Hero {
        uint256 generation;
        Tribe tribe;
        uint256 exp;
        uint256 dna;
        uint256 farmTime;
        uint256 bornTime;
    }


    uint256 public latestTokenId;
    mapping(uint256 => bool) public isEvolved;

    mapping(uint256 => Hero) internal heros;
    IERC20 public ganERC20;

    constructor(
        string memory _name,
        string memory _symbol,
        address _manager,
        address _ganERC20
    ) ERC721(_name, _symbol, _manager) {
        ganERC20 = IERC20(_ganERC20);
    }

    modifier onlyOperator() {
        require(manager.isOperator(msg.sender), "require Operator.");
        _;
    }

    

    function priceEgg() public view returns (uint256) {
        return manager.priceEgg();
    }

    function feeEvolve() public view returns (uint256) {
        return manager.feeEvolve();
    }

    function _mint(address to, uint256 tokenId) internal override(ERC721) {
        super._mint(to, tokenId);
        _incrementTokenId();
    }

    function working(uint256 _tokenId, uint256 _time) public onlyOperator {
        require(_time > 0, "no time");
        Hero storage hero = heros[_tokenId];
        hero.farmTime = hero.farmTime.add(_time);

        emit Working(_tokenId, _time);
    }

    function exp(uint256 _tokenId, uint256 _exp) public onlyOperator {
        require(_exp > 0, "no exp");
        Hero storage hero = heros[_tokenId];
        hero.exp = hero.exp.add(_exp);
        emit Exp(_tokenId, _exp);
    }

    function evolve(
        uint256 _tokenId,
        address _owner,
        uint256 _dna
    ) public onlyOperator {
        require(ownerOf(_tokenId) == _owner, "not own");
        Hero storage hero = heros[_tokenId];
        require(!isEvolved[_tokenId], "require: not evolved");

        hero.bornTime = block.timestamp;
        hero.dna = _dna;

        emit Evolve(_tokenId, _dna);
    }

    function changeTribe(
        uint256 _tokenId,
        address _owner,
        Tribe tribe
    ) external onlyOperator {
        require(ownerOf(_tokenId) == _owner, "not own");
        ganERC20.transferFrom(
            _msgSender(),
            manager.feeAddress(),
            manager.feeChangeTribe()
        );

        Hero storage hero = heros[_tokenId];
        hero.tribe = tribe;

        emit UpdateTribe(_tokenId, tribe);
    }

    function layEgg(
        uint256 amount,
        address receiver,
        Tribe tribe
    ) external onlyOperator {
        require(amount > 0, "require: >0");
        if (amount == 1) _layEgg(receiver, tribe);
        else
            for (uint256 index = 0; index < amount; index++) {
                _layEgg(receiver, tribe);
            }
    }
    function mintHero(
        address receiver,
        Tribe tribe,
        uint256 dna
    ) external onlyOperator {
         uint256 nextTokenId = _getNextTokenId();
        _mint(receiver, nextTokenId);

        heros[nextTokenId] = Hero({
            generation: manager.generation(),
            tribe: tribe,
            exp: 0,
            dna: dna,
            farmTime: 0,
            bornTime: block.timestamp
        });
        emit LayEgg(nextTokenId, receiver);
    }
    
    function _layEgg(address receiver, Tribe tribe) internal {
        uint256 nextTokenId = _getNextTokenId();
        _mint(receiver, nextTokenId);

        heros[nextTokenId] = Hero({
            generation: manager.generation(),
            tribe: tribe,
            exp: 0,
            dna: 0,
            farmTime: 0,
            bornTime: block.timestamp
        });

        emit LayEgg(nextTokenId, receiver);
    }

    /**
     * @dev calculates the next token ID based on value of latestTokenId
     * @return uint256 for the next token ID
     */
    function _getNextTokenId() private view returns (uint256) {
        return latestTokenId.add(1);
    }

    /**
     * @dev increments the value of latestTokenId
     */
    function _incrementTokenId() private {
        latestTokenId++;
    }

    function getHero(uint256 _tokenId)
        public
        view
        returns (Hero memory)
    {
        return heros[_tokenId];
    }

    function heroLevel(uint256 _tokenId) public view returns (uint256) {
        return getLevel(getHero(_tokenId).exp);
    }
    function upgrade(uint256 _tokenId) public onlyOperator{
        uint256 rare = getRare(_tokenId);
        if(rare==1){
            heros[_tokenId].dna = 5050 * 10**26;
        }
        if(rare==2){
            heros[_tokenId].dna = 7900 * 10**26;
        } 
        if(rare==3){
            heros[_tokenId].dna = 8750 * 10**26;
        }
        if(rare==4){
            heros[_tokenId].dna = 9400 * 10**26;
        }
        if(rare==5){
            heros[_tokenId].dna = 9750 * 10**26;
        }
        
    }

    function getRare(uint256 _tokenId) public view returns (uint256) {
        uint256 dna = getHero(_tokenId).dna;
        // if (dna == 0) return 0;
        uint256 rareParser = dna / 10**26;
        if (rareParser < 5050) { //50%
            return 1;
        } else if (rareParser < 7900) {//28.5%
            return 2;
        } else if (rareParser < 8750) {//8.5%
            return 3;
        } else if (rareParser < 9400) {//6.5%
            return 4;
        } else if (rareParser < 9750) {//3.5%
            return 5;
        } else {//2.5%
            return 6;
        }
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