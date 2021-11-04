// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0 <0.9.0;
import "./Ownable.sol";
import "./SafeMath.sol";
contract GameManager  is Ownable  {
    using SafeMath for uint256;
    mapping(address=>bool) private operators;
    address private _spawnerAddress;
    address private _marketplaceAddress;
    address private _farmOwnersAddress;
    uint256 private _priceEgg;
    uint256 private _divPercent;
    uint256 private _feeChangeTribe;
    uint256 private _feeMarketRate;
    uint256 private _loseRate;
    uint256 private _feeEvolve;
    address private _feeAddress;
    uint256 private _currentGeneration;
    uint256 private _xBattle;
    uint256 private _commissionRateEgg;
    uint256 private _commissionRateMarket;
    mapping(uint256=>uint256) private _timesBattle;
    mapping(address=>bool) private _nftVisit;
    uint256 _timeLimitBattle;
    uint256 private _lastTimeStampForRandom;
    uint256 private _nftStakingAmount;
    uint256 private _minBalanceToPvP;
    //set
    function setOperators(address _address,bool _isOperator) external onlyOwner {
        operators[_address] = _isOperator;
    }
     function setNftVisit(address _address,bool _approve) external onlyOwner {
        _nftVisit[_address] = _approve;
    }
    function setNftStakingAmount(uint256 _value) external onlyOwner {
         _nftStakingAmount = _value;
    }
    function minBalanceToPvP(uint256 _value) external onlyOwner {
         _minBalanceToPvP = _value;
    }
    function setTimesBattle(uint256 rare,uint256 times) external onlyOwner {
         _timesBattle[rare]= times;
    }

    function setTimeLimitBattle(uint256 _value) external onlyOwner {
         _timeLimitBattle = _value;
    }

    function setGeneration(uint256 _value) external onlyOwner {
         _currentGeneration = _value;
    }
    function setXBattle(uint256 _value) external onlyOwner {
         _xBattle = _value;
    }

    function setPriceEgg(uint256 _value) external onlyOwner {
         _priceEgg = _value;
    }

    function setDivPercent(uint256 _value) external onlyOwner {
         _divPercent = _value;
    }

    function setFeeChangeTribe(uint256 _value) external onlyOwner {
         _feeChangeTribe = _value;
    }

    function setFeeMarketRate(uint256 _value) external onlyOwner {
         _feeMarketRate = _value;
    }

    function setLoseRate(uint256 _value) external onlyOwner {
         _loseRate = _value;
    }

    function setFeeEvolve(uint256 _value) external onlyOwner {
         _feeEvolve = _value;
    }

    function setFeeAddress(address _address) external onlyOwner {
         _feeAddress = _address;
    }

    function setCommissionRateEgg(uint256 _commission) external onlyOwner {
         _commissionRateEgg = _commission;
    }

    function setCommissionRateMarket(uint256 _commission) external onlyOwner {
         _commissionRateMarket = _commission;
    }
    //get
   
    function isOperator(address _address) external view returns (bool){

        return operators[_address];
    }
    function isNftVisit(address _address) external view returns (bool){

        return _nftVisit[_address];
    }
    function markets(address _address) view external returns (bool){

        return _address == _marketplaceAddress;
    }

    
    function timesBattle(uint256 rare)  view external returns (uint256){

        return _timesBattle[rare];
    }

    function timeLimitBattle() external  view returns (uint256){

        return _timeLimitBattle;
    }

    function generation() external  view returns (uint256){
        return _currentGeneration;
    }

    function xBattle() external  view returns (uint256){

        return _xBattle;
    }

    function priceEgg() external view returns (uint256){
        return _priceEgg;
    }

    function divPercent() external view returns (uint256){
        return _divPercent;
    }

    function feeChangeTribe() external view returns (uint256){
        return _feeChangeTribe;
    }

    function feeMarketRate() external view returns (uint256){
        return _feeMarketRate;
    }

    function loseRate() external view returns (uint256){
        return _loseRate;
    }

    function feeEvolve() external view returns (uint256){
        return _feeEvolve;
    }

    function feeAddress() external view returns (address){
        return _feeAddress;
    }

    function updateSeedForRandom() external {
         _lastTimeStampForRandom = _lastTimeStampForRandom.add(1);
    }

    function getSeedForRandom() external view returns (uint256){

        uint256 _seed = _lastTimeStampForRandom;
        return _seed;
    }
    function commissionRateEgg() external view returns(uint256) {
         return _commissionRateEgg;
    }
    
    function commissionRateMarket() external view returns(uint256) {
        return _commissionRateMarket;
    }
    function nftStakingAmount() external view returns(uint256) {
        return _nftStakingAmount;
    }
    function minBalanceToPvP() external view returns(uint256) {
        return _minBalanceToPvP;
    }
    
}