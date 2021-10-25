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

contract GalacticArenaMarketPlace is 
    Initializable,
    AccessControlUpgradeable,
    OwnableUpgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    event PlaceOrder(uint256 indexed tokenId, address seller, uint256 price);
    event CancelOrder(uint256 indexed tokenId, address seller);
    event UpdatePrice(
        uint256 indexed tokenId,
        address seller,
        uint256 newPrice
    );
    event FillOrder(uint256 indexed tokenId, address seller);

    struct ItemSale {
        uint256 tokenId;
        address owner;
        uint256 price;
        uint256 orderBlockTime;
        address nftAddress;
        address currency;
    }

    mapping(uint256 => ItemSale) internal markets;
    mapping(uint256 => uint256) public latestBlockTransfer;

    EnumerableSet.UintSet private tokenSales;
    mapping(address => EnumerableSet.UintSet) private sellerTokens;
    mapping(address => bool) private userBlacklist;
    mapping(uint256 => bool) private nftIdBlacklist;
    
    ManagerInterface public manager;
    IERC20 public ganERC20;
    GalacticArenaNFT public ganNFT;
    IRef public ref;
    bytes32 public constant MARKETPLACE_ADMIN = keccak256("MARKETPLACE_ADMIN");

    function initialize(
        address _manager,
        address _ganERC20,
        address _ganNFT,
        address _ref
    ) public initializer {
        __AccessControl_init_unchained();
        __Ownable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MARKETPLACE_ADMIN, msg.sender);

        manager = ManagerInterface(_manager);
        ganERC20 = IERC20(_ganERC20);
        ganNFT = GalacticArenaNFT(_ganNFT);
        ref = IRef(_ref);
    }

    function setUserBlacklist(address user, bool value) public onlyOwner {
        userBlacklist[user] = value;
    }

    function setNftIdBlacklist(uint256 tokenId, bool value) public onlyOwner {
        nftIdBlacklist[tokenId] = value;
    }

    function placeOrder(uint256 _tokenId, uint256 _price,address _currency) payable public {
        require(ganNFT.ownerOf(_tokenId) == _msgSender(), "not own");
        require(_price > 0, "nothing is free");
        // require(ganNFT.evolved(_tokenId), "require: evolved");
        ItemSale storage itemSale = markets[_tokenId];
        require(itemSale.tokenId == 0, "Order exists");
        require(userBlacklist[_msgSender()] == false, "user blacklisted");
        require(nftIdBlacklist[_tokenId] == false, "nft blacklisted");
        require(latestBlockTransfer[_tokenId] < block.number, "Access denied");
        
        latestBlockTransfer[_tokenId] = block.number;
        if (tokenSales.contains(_tokenId)){
            if (sellerTokens[_msgSender()].contains(_tokenId)) {
                transferAndStore(_tokenId, _price,_currency);
            }
            else{
                sellerTokens[_msgSender()].add(_tokenId);
                transferAndStore(_tokenId, _price,_currency);
            }
        }else{
            tokenSales.add(_tokenId);
            if (sellerTokens[_msgSender()].contains(_tokenId)){
                transferAndStore(_tokenId, _price,_currency);
            }
            else{
                sellerTokens[_msgSender()].add(_tokenId);
                transferAndStore(_tokenId, _price,_currency);
            }
        }
        emit PlaceOrder(_tokenId, _msgSender(), _price);
    }

    function transferAndStore(uint256 _tokenId, uint256 _price,address _currency) internal {
        ganNFT.transferFrom(_msgSender(),address(this), _tokenId);
        markets[_tokenId] = ItemSale({
            tokenId: _tokenId,
            price: _price,
            owner: _msgSender(),
            orderBlockTime: block.timestamp,
            nftAddress: address(ganNFT),
            currency: _currency
        });
    }

    function cancelOrder(uint256 _tokenId) public {
        ItemSale storage itemSale = markets[_tokenId];
        require(itemSale.owner == _msgSender(), "not own");
        ganNFT.transferFrom(address(this),itemSale.owner, _tokenId);
       
        tokenSales.remove(_tokenId);
        sellerTokens[itemSale.owner].remove(_tokenId);
        markets[_tokenId] = ItemSale({
            tokenId: 0,
            price: 0,
            owner: address(0),
            orderBlockTime: 0,
            nftAddress: address(0),
            currency: address(0)
        });
        emit CancelOrder(_tokenId, _msgSender());
    }

    function updatePrice(uint256 _tokenId, uint256 _price) public {
        require(_price > 0, "nothing is free");
        require(tokenSales.contains(_tokenId), "not sale");
        ItemSale storage itemSale = markets[_tokenId];
        require(itemSale.owner == _msgSender(), "not own");

        itemSale.price = _price;

        emit UpdatePrice(_tokenId, _msgSender(), _price);
    }

    function fillOrder(uint256 _tokenId) public payable {
        require(tokenSales.contains(_tokenId), "not sale");
        require(
            latestBlockTransfer[_tokenId] < block.number,
            "denied"
        );
        ItemSale storage itemSale = markets[_tokenId];

        uint256 feeMarket = itemSale.price.mul(manager.feeMarketRate()).div(
            manager.divPercent()
        );
        address refAccount = ref.getReferences(_msgSender());
         uint feeCommission =0;
        if(refAccount!=address(0)){
            feeCommission = feeMarket.mul(manager.commissionRateMarket()).div(100);
            feeMarket = feeMarket.sub(feeCommission);
        }
        if(itemSale.currency==address(0)){
            require(msg.value>=itemSale.price,"msg.value not enough");
            payable(itemSale.owner).transfer(msg.value.sub(feeMarket).sub(feeCommission));
            payable(manager.feeAddress()).transfer(feeMarket);
            if(feeCommission>0){
                 ganERC20.transferFrom(_msgSender(), refAccount, feeCommission);
            }
        }
        else{
            ganERC20.transferFrom(
                _msgSender(),
                itemSale.owner,
                itemSale.price.sub(feeMarket).sub(feeCommission)
            );   
             ganERC20.transferFrom(
                _msgSender(),
                manager.feeAddress(),
                feeMarket
            );   
             if(feeCommission>0){
                 ganERC20.transferFrom(_msgSender(), refAccount, feeCommission);
            }
        }
        ganNFT.transferFrom(address(this),_msgSender(), _tokenId);
        tokenSales.remove(_tokenId);
        sellerTokens[itemSale.owner].remove(_tokenId);
        markets[_tokenId] = ItemSale({
            tokenId: 0,
            price: 0,
            owner: address(0),
            orderBlockTime: 0,
            nftAddress: address(0),
            currency:address(0)
        });

        emit FillOrder(_tokenId, _msgSender());
    }

   
    function marketsSize() public view returns (uint256) {
        return tokenSales.length();
    }

    function orders(address _seller) public view returns (uint256) {
        return sellerTokens[_seller].length();
    }

    function tokenSaleByIndex(uint256 index) public view returns (uint256) {
        return tokenSales.at(index);
    }

    function tokenSaleOfOwnerByIndex(address _seller, uint256 index)
        public
        view
        returns (uint256)
    {
        return sellerTokens[_seller].at(index);
    }

    function getSale(uint256 _tokenId) public view returns (ItemSale memory) {
        if (tokenSales.contains(_tokenId)) return markets[_tokenId];
        return ItemSale({tokenId: 0, owner: address(0), price: 0, orderBlockTime: 0, nftAddress: address(0),currency:address(0)});
    }


}
