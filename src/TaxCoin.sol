// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {IERC20, Ownable} from "./utils/LPDiv.sol";
import "./utils/IVeloV2.sol";
import "./TaxCoinDividendTracker.sol";
import "./Coin.sol";
import "./ITaxCoin.sol";

contract TaxCoin is Ownable, ITaxCoin {
    IVeloV2 public router;
    Coin public coin;
    address public pair;

    bool public claimEnabled;
    bool public tradingEnabled;

    mapping(address => bool) public _isExcludedFromFees;
    mapping(address => bool) public automatedMarketMakerPairs;
    mapping(address => bool) public _isExcludedFromMaxWallet;

    TaxCoinDividendTracker public dividendTracker;

    address public devWallet;
    address public tokenOut;

    uint256 public swapTokensAtAmount;
    uint256 public maxBuyAmount;
    uint256 public maxSellAmount;
    uint256 public maxWallet;

    mapping(address => bool) public _isBot;

    constructor(
        address _developerwallet, 
        address _tokenIn,
        address _tokenOut, 
        address Vrouter, 
        address VPair) {
        dividendTracker = new TaxCoinDividendTracker();
        setDevWallet(_developerwallet);
        coin = Coin(_tokenIn);
        tokenOut = _tokenOut;

        IVeloV2 _router = IVeloV2(Vrouter);
        address _pair = VPair;

        router = _router;
        pair = _pair;
        setSwapTokensAtAmount(300000); //
        updateMaxWalletAmount(2000000);
        setMaxBuyAndSell(2000000, 2000000);

        _setAutomatedMarketMakerPair(_pair, true);

        dividendTracker.updateLP_Token(pair);

        dividendTracker.excludeFromDividends(address(dividendTracker), true);
        dividendTracker.excludeFromDividends(address(this), true);
        dividendTracker.excludeFromDividends(owner(), true);
        dividendTracker.excludeFromDividends(address(0xdead), true);
        dividendTracker.excludeFromDividends(address(_router), true);

        excludeFromMaxWallet(address(_pair), true);
        excludeFromMaxWallet(address(this), true);
        excludeFromMaxWallet(address(_router), true);

        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);

        coin.mint(owner(), 100000000 * (10 ** 18));
    }

    receive() external payable {}

    function updateDividendTracker(address newAddress) public onlyOwner {
        TaxCoinDividendTracker newDividendTracker = TaxCoinDividendTracker(payable(newAddress));
        newDividendTracker.excludeFromDividends(address(newDividendTracker), true);
        newDividendTracker.excludeFromDividends(address(this), true);
        newDividendTracker.excludeFromDividends(owner(), true);
        newDividendTracker.excludeFromDividends(address(router), true);
        dividendTracker = newDividendTracker;
    }

    /// @notice Manual claim the dividends
    function claim() external {
        require(claimEnabled, "Claim not enabled");
        dividendTracker.processAccount(payable(msg.sender));
    }

    function updateMaxWalletAmount(uint256 newNum) public onlyOwner {
        require(newNum >= 1000000, "Cannot set maxWallet lower than 1%");
        maxWallet = newNum * 10 ** 18;
    }

    function setMaxBuyAndSell(uint256 maxBuy, uint256 maxSell) public onlyOwner {
        require(maxBuy >= 1000000, "Cannot set maxbuy lower than 1% ");
        require(maxSell >= 500000, "Cannot set maxsell lower than 0.5% ");
        maxBuyAmount = maxBuy * 10 ** 18;
        maxSellAmount = maxSell * 10 ** 18;
    }

    function setSwapTokensAtAmount(uint256 amount) public onlyOwner {
        swapTokensAtAmount = amount * 10 ** 18;
    }

    function excludeFromMaxWallet(address account, bool excluded) public onlyOwner {
        _isExcludedFromMaxWallet[account] = excluded;
    }

    /// @notice Withdraw tokens sent by mistake.
    /// @param tokenAddress The address of the token to withdraw
    function rescueETH20Tokens(address tokenAddress) external onlyOwner {
        IERC20(tokenAddress).transfer(owner(), IERC20(tokenAddress).balanceOf(address(this)));
    }

    /// @notice Send remaining ETH to dev
    /// @dev It will send all ETH to dev
    function forceSend() external onlyOwner {
        uint256 ETHbalance = address(this).balance;
        (bool success,) = payable(devWallet).call{value: ETHbalance}("");
        require(success);
    }

    function trackerRescueETH20Tokens(address tokenAddress) external onlyOwner {
        dividendTracker.trackerRescueETH20Tokens(msg.sender, tokenAddress);
    }

    function updateRouter(address newRouter) external onlyOwner {
        router = IVeloV2(newRouter);
    }

    /////////////////////////////////
    // Exclude / Include functions //
    /////////////////////////////////

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromFees[account] != excluded, "Account is already the value of 'excluded'");
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    /// @dev "true" to exlcude, "false" to include
    function excludeFromDividends(address account, bool value) public onlyOwner {
        dividendTracker.excludeFromDividends(account, value);
    }

    function setDevWallet(address newWallet) public onlyOwner {
        devWallet = newWallet;
    }

    function activateTrading() external onlyOwner {
        require(!tradingEnabled, "Trading already enabled");
        tradingEnabled = true;
    }

    function setClaimEnabled(bool state) external onlyOwner {
        claimEnabled = state;
    }

    /// @param bot The bot address
    /// @param value "true" to blacklist, "false" to unblacklist
    function setBot(address bot, bool value) external onlyOwner {
        require(_isBot[bot] != value);
        _isBot[bot] = value;
    }

    function setLP_Token(address _lpToken) external onlyOwner {
        dividendTracker.updateLP_Token(_lpToken);
    }

    /// @dev Set new pairs created due to listing in new DEX
    function setAutomatedMarketMakerPair(address newPair, bool value) external onlyOwner {
        _setAutomatedMarketMakerPair(newPair, value);
    }

    function _setAutomatedMarketMakerPair(address newPair, bool value) private {
        require(automatedMarketMakerPairs[newPair] != value, "Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[newPair] = value;

        if (value) {
            dividendTracker.excludeFromDividends(newPair, true);
        }

        emit SetAutomatedMarketMakerPair(newPair, value);
    }

    //////////////////////
    // Getter Functions //
    //////////////////////

    function getTotalDividendsDistributed() external view returns (uint256) {
        return dividendTracker.totalDividendsDistributed();
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function withdrawableDividendOf(address account) public view returns (uint256) {
        return dividendTracker.withdrawableDividendOf(account);
    }

    function dividendTokenBalanceOf(address account) public view returns (uint256) {
        return dividendTracker.balanceOf(account);
    }

    function getAccountInfo(address account) external view returns (address, uint256, uint256, uint256, uint256) {
        return dividendTracker.getAccount(account);
    }
}
