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
            0x9dC6821AE74FaAE71Dfd1016f14eAdcA7823Faf4, //token paired
            0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858, //router
            0x5CFafe2E420544f2557aaF2C104778dFa6c4EF0D  //pool address
        );
        
        vm.stopBroadcast();

    }
}
