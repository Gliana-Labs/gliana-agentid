// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GlianaAgentTopUp, IAgentId} from "../src/GlianaAgentTopUp.sol";

/// Deploys GlianaAgentTopUp on BNB Chain. PAYEE (the address that receives top-ups) comes from the environment.
/// forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed.bnbchain.org --broadcast --verify --interactives 1
contract Deploy is Script {
    IAgentId constant AGENT_ID = IAgentId(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F);
    IERC20 constant USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant USDC = IERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);

    function run() external returns (GlianaAgentTopUp c) {
        address payee = vm.envAddress("PAYEE");
        vm.startBroadcast();
        c = new GlianaAgentTopUp(AGENT_ID, payee, USDT, USDC);
        vm.stopBroadcast();
        console.log("GlianaAgentTopUp", address(c));
    }
}
