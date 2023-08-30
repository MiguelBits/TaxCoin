// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {TaxCoin} from "../src/TaxCoin.sol";

contract TaxCoinScript is Script {

    function run() public returns(TaxCoin taxCoin){
        vm.startBroadcast();


        // deploy TaxCoin
        taxCoin = new TaxCoin("TaxCoiner");
        
        vm.stopBroadcast();

    }
}
