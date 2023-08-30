// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TaxCoinDividendTracker.sol";
import "./utils/IVeloV2.sol";

interface ITaxCoin {
    error InitAlreadyDone();
    ///////////////
    //   Events  //
    ///////////////

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    function pair() external view returns (address);
    function dividendTracker() external view returns (TaxCoinDividendTracker);
    function devWallet() external view returns (address);
    function tokenOut() external view returns (address);
    function router() external view returns (IVeloV2);
    function tradingEnabled() external view returns (bool);
    function automatedMarketMakerPairs(address) external view returns (bool);
    function _isExcludedFromFees(address) external view returns (bool);
    function _isExcludedFromMaxWallet(address) external view returns (bool);
    function swapTokensAtAmount() external view returns (uint256);
    function maxBuyAmount() external view returns (uint256);
    function maxSellAmount() external view returns (uint256);
    function maxWallet() external view returns (uint256);
}
