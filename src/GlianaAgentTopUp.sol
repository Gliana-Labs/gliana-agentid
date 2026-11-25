// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Minimal view of the SPACE ID Agent ID registry (ERC-721, non-transferable) on BNB Chain.
interface IAgentId {
    function balanceOf(address owner) external view returns (uint256);
}

/**
 * @title GlianaAgentTopUp
 * @notice An AI agent that holds a Binance Agent ID (name.ai) tops up its GlianaAI balance in a USD stablecoin.
 *         GlianaAI (https://ai.glianalabs.com) reads the TopUp event and credits the agent's prepaid balance,
 *         which pays for AI calls (chat, image, video, voice) at per-call prices.
 *
 * Non-custodial by construction:
 * - The contract never holds funds. Each top-up moves the tokens from the agent straight to `payee` in the same call.
 * - There is no owner, no admin, no pause, no upgrade, no mint, no withdraw. `payee`, the Agent ID registry and the
 *   accepted tokens are immutable, fixed at deployment.
 * - The agent signs every top-up itself (Binance Agentic Wallet: preview, then the user confirms execute).
 *   The contract can only move tokens the caller approved, and only in the call the caller makes.
 * - Tokens sent to this contract by a plain transfer (not through topUp) cannot be recovered: there is no rescue
 *   function, by design, because any function that moves tokens out would need an owner. Always use topUp.
 */
contract GlianaAgentTopUp {
    using SafeERC20 for IERC20;

    IAgentId public immutable agentId;
    address public immutable payee;
    IERC20 public immutable usdt;
    IERC20 public immutable usdc;

    /// @notice Smallest top-up: 0.10 USD (both tokens use 18 decimals on BNB Chain).
    uint256 public constant MIN_AMOUNT = 1e17;
    /// @notice Largest single top-up: 1,000 USD. A guard against a mistyped amount, not a limit on use.
    uint256 public constant MAX_AMOUNT = 1_000e18;

    event TopUp(address indexed agent, address indexed token, uint256 amount, bytes32 indexed ref);

    error NotAgentIdHolder();
    error UnsupportedToken();
    error AmountOutOfRange();
    error ZeroAddress();

    constructor(IAgentId agentId_, address payee_, IERC20 usdt_, IERC20 usdc_) {
        if (address(agentId_) == address(0) || payee_ == address(0) || address(usdt_) == address(0) || address(usdc_) == address(0)) {
            revert ZeroAddress();
        }
        agentId = agentId_;
        payee = payee_;
        usdt = usdt_;
        usdc = usdc_;
    }

    /// @notice True when `who` holds an Agent ID and so may top up.
    function isAgent(address who) public view returns (bool) {
        return agentId.balanceOf(who) > 0;
    }

    /**
     * @notice Top up `amount` of `token` (USDT or USDC on BNB Chain). Needs a prior `approve(this, amount)`.
     * @param ref Optional reference the agent chooses (e.g. a hash of its GlianaAI sign-in request); 0 for none.
     */
    function topUp(IERC20 token, uint256 amount, bytes32 ref) external {
        if (!isAgent(msg.sender)) revert NotAgentIdHolder();
        if (token != usdt && token != usdc) revert UnsupportedToken();
        if (amount < MIN_AMOUNT || amount > MAX_AMOUNT) revert AmountOutOfRange();
        token.safeTransferFrom(msg.sender, payee, amount);
        emit TopUp(msg.sender, address(token), amount, ref);
    }
}
