// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GlianaAgentTopUp, IAgentId} from "../src/GlianaAgentTopUp.sol";

contract MockToken is ERC20 {
    constructor(string memory n) ERC20(n, n) {}

    function mint(address to, uint256 a) external {
        _mint(to, a);
    }
}

contract MockAgentId is IAgentId {
    mapping(address => uint256) public bal;

    function set(address who, uint256 b) external {
        bal[who] = b;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return bal[owner];
    }
}

contract GlianaAgentTopUpTest is Test {
    event TopUp(address indexed agent, address indexed token, uint256 amount, bytes32 indexed ref);

    MockAgentId ids;
    MockToken usdt;
    MockToken usdc;
    MockToken other;
    GlianaAgentTopUp pay;
    address payee = address(0xBEEF);
    address agent = address(0xA11CE);
    address stranger = address(0xB0B);

    function setUp() public {
        ids = new MockAgentId();
        usdt = new MockToken("USDT");
        usdc = new MockToken("USDC");
        other = new MockToken("OTHER");
        pay = new GlianaAgentTopUp(ids, payee, usdt, usdc);
        ids.set(agent, 1);
        for (uint256 i; i < 2; i++) {
            MockToken t = i == 0 ? usdt : usdc;
            t.mint(agent, 10_000e18);
            t.mint(stranger, 10_000e18);
            vm.prank(agent);
            t.approve(address(pay), type(uint256).max);
            vm.prank(stranger);
            t.approve(address(pay), type(uint256).max);
        }
    }

    function test_topUpForwardsToPayeeAndHoldsNothing() public {
        vm.expectEmit(true, true, true, true);
        emit TopUp(agent, address(usdt), 5e18, bytes32(uint256(7)));
        vm.prank(agent);
        pay.topUp(usdt, 5e18, bytes32(uint256(7)));
        assertEq(usdt.balanceOf(payee), 5e18);
        assertEq(usdt.balanceOf(address(pay)), 0);
        assertEq(usdt.balanceOf(agent), 10_000e18 - 5e18);
    }

    function test_usdcAccepted() public {
        vm.prank(agent);
        pay.topUp(usdc, 1e18, 0);
        assertEq(usdc.balanceOf(payee), 1e18);
    }

    function test_rejectsNonHolder() public {
        vm.prank(stranger);
        vm.expectRevert(GlianaAgentTopUp.NotAgentIdHolder.selector);
        pay.topUp(usdt, 1e18, 0);
    }

    function test_rejectsOtherToken() public {
        other.mint(agent, 1e18);
        vm.prank(agent);
        vm.expectRevert(GlianaAgentTopUp.UnsupportedToken.selector);
        pay.topUp(IERC20(address(other)), 1e18, 0);
    }

    function test_amountBounds() public {
        vm.startPrank(agent);
        vm.expectRevert(GlianaAgentTopUp.AmountOutOfRange.selector);
        pay.topUp(usdt, 1e17 - 1, 0);
        vm.expectRevert(GlianaAgentTopUp.AmountOutOfRange.selector);
        pay.topUp(usdt, 1_000e18 + 1, 0);
        pay.topUp(usdt, 1e17, 0);
        pay.topUp(usdt, 1_000e18, 0);
        vm.stopPrank();
    }

    function test_holderLosingIdIsRejected() public {
        ids.set(agent, 0);
        vm.prank(agent);
        vm.expectRevert(GlianaAgentTopUp.NotAgentIdHolder.selector);
        pay.topUp(usdt, 1e18, 0);
    }

    function test_noApprovalReverts() public {
        vm.prank(agent);
        usdt.approve(address(pay), 0);
        vm.prank(agent);
        vm.expectRevert();
        pay.topUp(usdt, 1e18, 0);
    }

    function test_constructorRejectsZero() public {
        vm.expectRevert(GlianaAgentTopUp.ZeroAddress.selector);
        new GlianaAgentTopUp(ids, address(0), usdt, usdc);
    }

    function testFuzz_forwardsExactAmount(uint256 amount) public {
        amount = bound(amount, 1e17, 1_000e18);
        vm.prank(agent);
        pay.topUp(usdc, amount, 0);
        assertEq(usdc.balanceOf(payee), amount);
        assertEq(usdc.balanceOf(address(pay)), 0);
    }
}
