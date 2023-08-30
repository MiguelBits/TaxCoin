// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {ERC20, Ownable} from "./utils/LPDiv.sol";
import "./utils/IVeloV2.sol";
import {TaxCoinDividendTracker} from "./TaxCoinDividendTracker.sol";
import "./ITaxCoin.sol";

contract Coin is ERC20, Ownable {
    event SendDividends(uint256 tokensSwapped, uint256 amount);

    modifier onlyTaxer() {
        require(msg.sender == address(taxcoin), "Only TaxCoin can call this function");
        _;
    }

    struct Taxes {
        uint256 liquidity;
        uint256 dev;
    }

    bool private swapping;

    Taxes public buyTaxes = Taxes(3, 3);
    Taxes public sellTaxes = Taxes(3, 3);

    uint256 public totalBuyTax = 6;
    uint256 public totalSellTax = 6;

    bool public swapEnabled = true;
    address public tokenOut;
    ITaxCoin taxcoin;
    IVeloV2 public router;
    TaxCoinDividendTracker public dividendTracker;
    address pair;

    constructor() ERC20("TAX", "TAX") {}

    function setTaxCoin(ITaxCoin _taxCoin) external onlyOwner {
        taxcoin = _taxCoin;
        dividendTracker = taxcoin.dividendTracker();
        pair = taxcoin.pair();
        tokenOut = taxcoin.tokenOut();
        router = taxcoin.router();
    }

    function mint(address to, uint256 amount) external onlyTaxer {
        _mint(to, amount);
    }

    function setBuyTaxes(uint256 _liquidity, uint256 _dev) external onlyOwner {
        require(_liquidity + _dev <= 20, "Fee must be <= 20%");
        buyTaxes = Taxes(_liquidity, _dev);
        totalBuyTax = _liquidity + _dev;
    }

    function setSellTaxes(uint256 _liquidity, uint256 _dev) external onlyOwner {
        require(_liquidity + _dev <= 20, "Fee must be <= 20%");
        sellTaxes = Taxes(_liquidity, _dev);
        totalSellTax = _liquidity + _dev;
    }

    /// @notice Enable or disable internal swaps
    /// @dev Set "true" to enable internal swaps for liquidity, treasury and dividends
    function setSwapEnabled(bool _enabled) external onlyOwner {
        swapEnabled = _enabled;
    }

    ////////////////////////
    // Transfer Functions //
    ////////////////////////

    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (!taxcoin._isExcludedFromFees(from) && !taxcoin._isExcludedFromFees(to) && !swapping) {
            require(taxcoin.tradingEnabled(), "Trading not active");
            if (taxcoin.automatedMarketMakerPairs(to)) {
                require(amount <= taxcoin.maxSellAmount(), "You are exceeding taxcoin.maxSellAmount()");
            } else if (taxcoin.automatedMarketMakerPairs(from)) {
                require(amount <= taxcoin.maxBuyAmount(), "You are exceeding taxcoin.maxBuyAmount");
            }
            if (!taxcoin._isExcludedFromMaxWallet(to)) {
                require(amount + balanceOf(to) <= taxcoin.maxWallet(), "Unable to exceed Max Wallet");
            }
        }

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= taxcoin.swapTokensAtAmount();

        if (
            canSwap && !swapping && swapEnabled && taxcoin.automatedMarketMakerPairs(to)
                && !taxcoin._isExcludedFromFees(from) && !taxcoin._isExcludedFromFees(to)
        ) {
            swapping = true;

            if (totalSellTax > 0) {
                swapAndLiquify(taxcoin.swapTokensAtAmount());
            }

            swapping = false;
        }

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (taxcoin._isExcludedFromFees(from) || taxcoin._isExcludedFromFees(to)) {
            takeFee = false;
        }

        if (!taxcoin.automatedMarketMakerPairs(to) && !taxcoin.automatedMarketMakerPairs(from)) {
            takeFee = false;
        }

        if (takeFee) {
            uint256 feeAmt;
            if (taxcoin.automatedMarketMakerPairs(to)) {
                feeAmt = (amount * totalSellTax) / 100;
            } else if (taxcoin.automatedMarketMakerPairs(from)) {
                feeAmt = (amount * totalBuyTax) / 100;
            }

            amount = amount - feeAmt;
            super._transfer(from, address(this), feeAmt);
        }
        super._transfer(from, to, amount);

        try dividendTracker.setBalance(from, balanceOf(from)) {} catch {}
        try dividendTracker.setBalance(to, balanceOf(to)) {} catch {}
    }

    function swapAndLiquify(uint256 tokens) private {
        uint256 toSwapForLiq = ((tokens * sellTaxes.liquidity) / totalSellTax) / 2;
        uint256 tokensToAddLiquidityWith = ((tokens * sellTaxes.liquidity) / totalSellTax) / 2;
        uint256 toSwapForDev = (tokens * sellTaxes.dev) / totalSellTax;

        swapTokensForETH(toSwapForLiq);

        uint256 currentbalance = address(this).balance;

        if (currentbalance > 0) {
            // Add liquidity to uni
            addLiquidity(tokensToAddLiquidityWith, currentbalance);
        }

        swapTokensForETH(toSwapForDev);

        uint256 EthTaxBalance = address(this).balance;

        // Send ETH to dev
        uint256 devAmt = EthTaxBalance;

        if (devAmt > 0) {
            (bool success,) = payable(taxcoin.devWallet()).call{value: devAmt}("");
            require(success, "Failed to send ETH to dev wallet");
        }

        uint256 lpBalance = IERC20(pair).balanceOf(address(this));

        //Send LP to dividends
        uint256 dividends = lpBalance;

        if (dividends > 0) {
            bool success = IERC20(pair).transfer(address(dividendTracker), dividends);
            if (success) {
                dividendTracker.distributeLPDividends(dividends);
                emit SendDividends(tokens, dividends);
            }
        }
    }

    // transfers LP from the owners wallet to holders // must approve this contract, on pair contract before calling
    function ManualLiquidityDistribution(uint256 amount) public onlyOwner {
        bool success = IERC20(pair).transferFrom(msg.sender, address(dividendTracker), amount);
        if (success) {
            dividendTracker.distributeLPDividends(amount);
        }
    }

    function swapTokensForETH(uint256 tokenAmount) private {
        IVeloV2.Route[] memory route = new IVeloV2.Route[](1);
        route[0] = IVeloV2.Route(address(this), address(router.weth()), false, address(router.defaultFactory()));

        _approve(address(this), address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            route,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(router), tokenAmount);

        // add the liquidity
        router.addLiquidity(
            address(this),
            tokenOut,
            false,
            tokenAmount,
            ethAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }
}
