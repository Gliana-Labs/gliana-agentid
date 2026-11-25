---
name: glianaai-agent-id
description: Use GlianaAI (170+ AI models: chat, image, video, voice, music) with a Binance Agent ID. Sign in with the Agentic Wallet, top up a prepaid balance in USDT/USDC on BNB Chain, then call any model with a gk_ API key. Use when the user wants their agent to generate images, video, speech or text through GlianaAI, or to fund GlianaAI from their Agentic Wallet.
---

# GlianaAI with a Binance Agent ID

GlianaAI (https://ai.glianalabs.com) is one OpenAI-compatible API for 170+ AI models, paid per call from a prepaid
balance. An Agentic Wallet that holds an Agent ID (`name.ai`) can sign in and fund that balance on BNB Chain.

API base: `https://api.glianalabs.com`. Contract: `GlianaAgentTopUp`
`0x37E97cE5681D28d86337a481dda470fd3FE19ACc` (BNB Chain, verified, no owner; it forwards each top-up straight to
GlianaAI and holds nothing).

## Rules

- Every `execute` step needs the user's explicit yes first. Show what it does (amount, token, contract) and wait.
  Never skip the preview or the confirmation in the Binance App.
- Never ask for, read or print a seed phrase or private key. Only the Agentic Wallet signs.
- Store the `gk_` key like a password: never paste it into public places. It spends the balance (capped at $5 a day).
- `baw contract-call` needs Developer Mode, which only the user can turn on in the Binance App (Agentic Wallet
  management, Settings). If a call fails because it is off, ask the user to turn it on.

## 1. Sign in (once): get a gk_ key

1. Get a challenge for the Agentic Wallet address:

   ```
   curl -s -X POST https://api.glianalabs.com/v1/agentid/challenge -H 'content-type: application/json' -d '{"address":"<agentWallet>"}'
   ```

   Keep `nonce`, `issued_at` and `typed_data_v4` from the answer. The challenge expires in 10 minutes.

2. Sign `typed_data_v4` with the Agentic Wallet. It is a sign-in message; it moves no funds:

   ```
   baw sign-message preview --binanceChainId 56 --signType EIP712 --message '{"method":"eth_signTypedData_v4","params":["<agentWallet>","<typed_data_v4 as a JSON string>"]}' --json
   baw sign-message execute --requestId <requestId> --json
   ```

3. Exchange the signature for a key:

   ```
   curl -s -X POST https://api.glianalabs.com/v1/agentid/key -H 'content-type: application/json' -d '{"address":"<agentWallet>","nonce":"<nonce>","issued_at":<issued_at>,"signature":"<signature>"}'
   ```

   The answer has `key` (`gk_…`). `403 no_agent_id` means the wallet holds no Agent ID: the user claims one in the
   Binance App (Wallet > homepage banner > Agent ID).

## 2. Top up (USDT or USDC on BNB Chain, $0.10 to $1,000)

1. Get the two ready-made transactions for the amount:

   ```
   curl -s 'https://api.glianalabs.com/v1/agentid/topup/calldata?usd=1&token=USDT'
   ```

2. Approve the token for the contract (`approve.to`, `approve.data`), after the user says yes:

   ```
   baw contract-call preview --binanceChainId 56 --from <agentWallet> --to <approve.to> --inputData <approve.data> --json
   baw contract-call execute --requestId <requestId> --json
   ```

3. Top up (`topup.to`, `topup.data`), after the user says yes:

   ```
   baw contract-call preview --binanceChainId 56 --from <agentWallet> --to <topup.to> --inputData <topup.data> --json
   baw contract-call execute --requestId <requestId> --json
   ```

4. Credit it at once with the transaction hash (otherwise it is credited within about 15 minutes):

   ```
   curl -s -X POST https://api.glianalabs.com/v1/agentid/topup/check -H 'content-type: application/json' -d '{"tx_hash":"<topUp tx hash>"}'
   ```

   `202 pending` means not confirmed yet: wait a few seconds and ask again.

## 3. Use it

Balance:

```
curl -s https://api.glianalabs.com/v1/keys/balance -H 'authorization: Bearer <gk_key>'
```

Chat (OpenAI-compatible; models at https://ai.glianalabs.com/models):

```
curl -s https://api.glianalabs.com/v1/chat/completions -H 'authorization: Bearer <gk_key>' -H 'content-type: application/json' -d '{"model":"claude-haiku-5.5","messages":[{"role":"user","content":"Hello"}]}'
```

Image:

```
curl -s https://api.glianalabs.com/v1/images/generations -H 'authorization: Bearer <gk_key>' -H 'content-type: application/json' -d '{"model":"z-image-turbo","prompt":"a lighthouse at dawn"}'
```

Every endpoint and price: https://ai.glianalabs.com/docs. Prices are per call; a failed call is not charged.
