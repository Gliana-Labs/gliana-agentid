# GlianaAI × Binance Agent ID

Pay-per-call AI for AI agents, with a Binance **Agent ID** (`name.ai`) as the account.

An agent whose Binance Agentic Wallet holds an Agent ID can sign in to [GlianaAI](https://ai.glianalabs.com) with one
signature and fund its balance on BNB Chain. The balance then pays for 170+ models (chat, image, video, voice, music)
through one OpenAI-compatible API. Built for the Binance Wallet × BNB Chain Agent ID Hackathon.

## Deployed (BNB Chain mainnet)

| | |
|---|---|
| `GlianaAgentTopUp` | [`0x37E97cE5681D28d86337a481dda470fd3FE19ACc`](https://bscscan.com/address/0x37E97cE5681D28d86337a481dda470fd3FE19ACc#code) (verified on BscScan and Sourcify) |
| Deploy tx | [`0x2022270d…2caada`](https://bscscan.com/tx/0x2022270d5cdb0e07d5a5513336dc8b6a2eab8fa8530ceb5d42a7d59f322caada), block 135710797 |
| Payee | `0x7662E00f8Ab4C362166e1FF649Ff6c2A638c80AD` |
| API | `https://api.glianalabs.com/v1/agentid` |

## How it works

1. **Sign in (identity).** `POST https://api.glianalabs.com/v1/agentid/challenge {address}` returns EIP-712 typed data.
   The agent signs it with the Agentic Wallet (`baw sign-message`, signType `EIP712`) and sends it to
   `POST /v1/agentid/key`. GlianaAI checks the signature and that the address holds an Agent ID, then returns a `gk_` API
   key. The signature moves no funds.
2. **Top up (payments).** The agent approves USDT or USDC and calls `topUp(token, amount, ref)` on
   [`GlianaAgentTopUp`](src/GlianaAgentTopUp.sol). The contract checks the Agent ID (access control) and forwards the
   tokens straight to GlianaAI in the same call.
3. **Use it.** `POST /v1/agentid/topup/check {tx_hash}` credits the balance at once (a scan also credits every ~15 min).
   Then call any endpoint with `Authorization: Bearer gk_…`, e.g. `POST /v1/chat/completions`.

## The contract

`GlianaAgentTopUp` (BNB Chain, Solidity 0.8.28, MIT):

- `topUp(IERC20 token, uint256 amount, bytes32 ref)`: caller must hold an Agent ID (`balanceOf > 0` on
  `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`); token must be BSC USDT or USDC; 0.10 to 1,000 USD per call. Emits
  `TopUp(agent, token, amount, ref)`.
- `isAgent(address)`: whether an address may top up.

**Owner permissions: none.** No owner, admin, pause, upgrade, mint, fee change, freeze or withdraw. The payee, the
Agent ID registry and the two tokens are immutable, set at deployment. The contract never holds funds: each top-up is
a single `transferFrom(agent, payee, amount)` the agent itself signs and confirms.

## Build and test

```bash
forge test
```

## Deploy

```bash
PAYEE=0x… forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed.bnbchain.org --broadcast --verify --interactives 1
```
