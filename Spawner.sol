// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0 <0.9.0;
pragma abicoder v2;

import "./Ownable.sol";
import "./GalacticArenaNFT.sol";
import "./IRef.sol";
contract Spawner is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Spawn(
        address indexed buyer,
        uint256 amount,
        GalacticArenaNFT.Tribe _tribe
    );
    event Evolve(uint256 indexed tokenId, address owner, uint256 dna);

    ManagerInterface public manager;
    GalacticArenaNFT public ganNFT;
    IERC20 public ganERC20;
    IRef public ref;
    uint256 public priceHero;
    uint256 public priceBox;
    constructor(
        address _manager,
        address _ganERC20,
        address _ganNFT,
        address _ref
    ) {
        manager = ManagerInterface(_manager);
        ganERC20 = IERC20(_ganERC20);
        ganNFT = GalacticArenaNFT(_ganNFT);
        ref = IRef(_ref);
    }

    function setManager(address _config) public onlyOwner {
        manager = ManagerInterface(_config);
    }

    function setNFT(address _ganNFT) public onlyOwner {
        ganNFT = GalacticArenaNFT(_ganNFT);
    }

    function setERC20(address _ganERC20) public onlyOwner {
        ganERC20 = IERC20(_ganERC20);
    }
    function setPriceBox(uint256 _price) public onlyOwner{
        priceBox = _price;
    }
    function setPriceHero(uint256 _price) public onlyOwner{
        priceHero = _price;
    }
    
    function lay(uint256 _amount) external {
        require(_amount > 0, "dont accept 0 amount");
        uint256 totalFee = priceBox.mul(_amount);
        address refAccount = ref.getReferences(_msgSender());
        if(refAccount!=address(0)){
            uint feeCommission = totalFee.mul(manager.commissionRateEgg()).div(100);
            totalFee = totalFee.sub(feeCommission);
            ganERC20.transferFrom(_msgSender(), refAccount, feeCommission);
        }
        ganERC20.transferFrom(_msgSender(), manager.feeAddress(), totalFee);
        uint256 trible = random(_amount, 4);
        trible = trible % 6;
        ganNFT.layEgg(_amount, _msgSender(), GalacticArenaNFT.Tribe(trible));
        emit Spawn(_msgSender(), _amount, GalacticArenaNFT.Tribe(trible));
    }
    function evolveEgg(uint256 _tokenId) public {
        require(_msgSender() == tx.origin,"Do not try to cheat");
        uint256 dna = generateDNA(_tokenId);
        ganERC20.transferFrom(
            _msgSender(),
            manager.feeAddress(),
            manager.feeEvolve()
        );
        ganNFT.evolve(_tokenId, _msgSender(), dna);
        manager.updateSeedForRandom();
        emit Evolve(_tokenId, _msgSender(), dna);
    }
    function buyHero(GalacticArenaNFT.Tribe _tribe) public{
        uint256 totalFee = priceHero;
        address refAccount = ref.getReferences(_msgSender());
        if(refAccount!=address(0)){
            uint feeCommission = totalFee.mul(manager.commissionRateEgg()).div(100);
            totalFee = totalFee.sub(feeCommission);
            ganERC20.transferFrom(_msgSender(), refAccount, feeCommission);
        }
        ganERC20.transferFrom(_msgSender(), manager.feeAddress(), totalFee);
        ganNFT.mintHero(_msgSender(),_tribe,10**29);
        emit Spawn(_msgSender(), 1, _tribe);
    }
    function generateDNA(uint256 _tokenId) public view returns (uint256) {
        uint256 dna = random(_tokenId, 30);
        while (dna < 10**26) {
            dna = random(_tokenId, 30);
        }
        return dna;
    }

    function forceEvolve(uint256 _tokenId, uint256 _dna) public onlyOwner {
        ganNFT.evolve(_tokenId, ganNFT.ownerOf(_tokenId), _dna);
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

