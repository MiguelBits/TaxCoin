// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {TaxCoin} from "../src/TaxCoin.sol";

contract TaxCoinScript is Script {

    function run() public returns(TaxCoin taxCoin){
        vm.startBroadcast();


        // deploy TaxCoin
        taxCoin = new TaxCoin(
            0xdC887AE5c6052baDC5D17a4eB2350b309cb2025f, //dev wallet
            0x4200000000000000000000000000000000000006, //token paired
            0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858 //router
        );
        
        vm.stopBroadcast();

    }
}
