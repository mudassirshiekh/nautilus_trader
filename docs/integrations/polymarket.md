# Polymarket

:::info
We are currently working on this integration guide.
:::

Founded in 2020, Polymarket is the world’s largest decentralized prediction market platform,
enabling traders to speculate on the outcomes of world events by buying and selling binary option shares using cryptocurrency.

NautilusTrader provides a venue integration for data and execution via Polymarket's Central Limit Order Book (CLOB) API.
The integration leverages the [official Python CLOB client library](https://github.com/Polymarket/py-clob-client)
to facilitate interaction with the Polymarket platform.

NautilusTrader is designed to work with Polymarket's signature type 0 (EOA), supporting EIP712 signatures from externally owned accounts.
This integration ensures that traders can execute orders securely and efficiently, using the most common on-chain signature method,
while NautilusTrader abstracts the complexity of signing and preparing orders for seamless execution.

## Binary options

A [binary option](https://en.wikipedia.org/wiki/Binary_option) is a type of financial exotic option contract in which traders bet on the outcome of a yes-or-no proposition.
If the prediction is correct, the trader receives a fixed payout; otherwise, they receive nothing.

All assets traded on Polymarket are quoted and settled in **USDC.e (PoS)**, with the contract address [0x2791bca1f2de4661ed88a30c99a7a9449aa84174](https://polygonscan.com/address/0x2791bca1f2de4661ed88a30c99a7a9449aa84174) on the Polygon blockchain.
**USDC.e** is a bridged version of USDC from Ethereum to the Polygon network, operating on Polygon's **Proof of Stake (PoS)** chain.
This allows for the use of USDC on Polygon with faster, more cost-efficient transactions, while being backed by USDC on Ethereum.

More information can be found in this [blog](https://polygon.technology/blog/phase-one-of-native-usdc-migration-on-polygon-pos-is-underway).

## Polymarket documentation

Polymarket offers comprehensive resources for different audiences:

- [Polymarket Learn](https://learn.polymarket.com/): Educational content and guides for users to understand the platform and how to engage with it.
- [Polymarket CLOB API](https://docs.polymarket.com/#introduction): Technical documentation for developers interacting with the Polymarket CLOB API.

## Overview

The following documentation assumes a trader is setting up for both live market
data feeds, and trade execution. The full Polymarket integration consists of an assortment of components,
which can be used together or separately depending on the users needs.

- `PolymarketWebSocketClient`: Low-level WebSocket API connectivity (built on top of the Nautilus `WebSocketClient` written in Rust).
- `PolymarketInstrumentProvider`: Instrument parsing and loading functionality for `BinaryOption` instruments.
- `PolymarketDataClient`: A market data feed manager.
- `PolymarketExecutionClient`: A trade execution gateway.
- `PolymarketLiveDataClientFactory`: Factory for Polymarket data clients (used by the trading node builder).
- `PolymarketLiveExecClientFactory`: Factory for Polymarket execution clients (used by the trading node builder).

:::note
Most users will simply define a configuration for a live trading node (as below),
and won't need to necessarily work with these lower level components directly.
:::

## Wallets and accounts

To interact with Polymarket via NautilusTrader, you’ll need a **Polygon**-compatible wallet (such as MetaMask).
The integration uses Externally Owned Account (EOA) signature types compatible with EIP712, meaning the wallet is directly owned by the trader/user.
This contrasts with the signature types used for Polymarket-administered wallets (such as those accessed via their user interface).

A single wallet address is supported per trader instance when using environment variables,
or multiple wallets could be configured with multiple `PolymarketExecutionClient` instances.

:::info
Ensure your wallet is funded with **USDC.e**, otherwise you will encounter the "not enough balance / allowance" API error when submitting orders.
:::

### Setting allowances for Polymarket contracts

Before you can start trading, you need to ensure that your wallet has allowances set for Polymarket's smart contracts.
You can do this by running the provided script located at `/adapters/polymarket/scripts/set_allowances.py`.

This script is adapted from a [gist](https://gist.github.com/poly-rodr/44313920481de58d5a3f6d1f8226bd5e) created by @poly-rodr.

:::note
You only need to run this script once per wallet that you intend to use for trading on Polymarket.
:::

This script automates the process of approving the necessary allowances for the Polymarket contracts.
It sets approvals for the USDC token and Conditional Token Framework (CTF) contract to allow the
Polymarket CLOB Exchange to interact with your funds.

Before running the script, ensure the following prerequisites are met:
- Install the web3 Python package: `pip install -U web3==5.28`
- Have a **Polygon** wallet funded with some MATIC (used for gas fees).
- Set the following environment variables in your shell:
  - `POLYGON_PRIVATE_KEY`: Your private key for the **Polygon** wallet.
  - `POLYGON_PUBLIC_KEY`: Your public key for the **Polygon** wallet.

Once you have these in place, the script will:

- Approve the maximum possible amount of USDC (using the `MAX_INT` value) for the Polymarket USDC token contract.
- Set the approval for the CTF contract, allowing it to interact with your account for trading purposes.

:::note
You can also adjust the approval amount in the script instead of using `MAX_INT`,
with the amount specified in units of **wma (wrapped market asset)**, though this has not been tested.
:::

Ensure that your private key and public key are correctly stored in the environment variables before running the script.
Here's an example of how to set the variables in your terminal session:

```bash
export POLYGON_PRIVATE_KEY="your_private_key"
export POLYGON_PUBLIC_KEY="your_public_key"
```

Run the script using:

```bash
python nautilus_trader/adapters/polymarket/scripts/set_allowances.py
```

### Script breakdown

The script performs the following actions:

- Connects to the Polygon network via an RPC URL (https://polygon-rpc.com/).
- Signs and sends a transaction to approve the maximum USDC allowance for Polymarket contracts.
- Sets approval for the CTF contract to manage Conditional Tokens on your behalf.
- Repeats the approval process for specific addresses like the Polymarket CLOB Exchange and Neg Risk Adapter.

This allows Polymarket to interact with your funds when executing trades and ensures smooth integration with the CLOB Exchange.

## Configuration

When setting up NautilusTrader to work with Polymarket, it’s crucial to properly configure the necessary parameters, particularly the private key.

**Key parameters**

- `private_key`: This is the private key for your external EOA wallet (_not_ the Polymarket wallet accessed through their GUI). This private key allows the system to sign and send transactions on behalf of the external account interacting with Polymarket. If not explicitly provided in the configuration, it will automatically source the `POLYMARKET_PK` environment variable.
- Ensure that the `POLYGON_PRIVATE_KEY` you are using corresponds to the external wallet used for trading and not the Polymarket wallet.
- `funder`: This refers to the **USDC.e** wallet address used for funding trades. Like the private key, if it’s not set, the `POLYMARKET_FUNDER` environment variable will be sourced.
- API credentials: You will need to provide the following API credentials to interact with the Polymarket CLOB:
  - `api_key`: If not provided, will source the `POLYMARKET_API_KEY` environment variable.
  - `api_secret`: If not provided, will source the `POLYMARKET_API_SECRET` environment variable.
  - `api_passphrase`: If not provided, will source the `POLYMARKET_API_PASSPHRASE` environment variable.

:::tip
It's recommended you use environment variables for API credentials.
:::

## Orders

The following order types are supported on Polymarket:
- `MARKET` (executed as a marketable limit order)
- `LIMIT`

The following time in force options are available:
- `GTC`: Good-Till-Canceled
- `GTD`: Good-Till-Date (second granularity based on UNIX time)
- `FOK`: Fill-Or-Kill

## Trades

Trades on Polymarket can have the following statuses:
- `MATCHED`: Trade has been matched and sent to the executor service by the operator, the executor service submits the trade as a transaction to the Exchange contract.
- `MINED`: Trade is observed to be mined into the chain, no finality threshold established.
- `CONFIRMED`: Trade has achieved strong probabilistic finality and was successful.
- `RETRYING`: Trade transaction has failed (revert or reorg) and is being retried/resubmitted by the operator.
- `FAILED`: Trade has failed and is not being retried.

Once a trade is initially matched, subsequent trade status updates will be received via the WebSocket.
NautilusTrader records the initial trade details in the `info` field of the `OrderFilled` event,
with additional trade events stored in the cache as JSON under a custom key to retain this information.

## Limitations and considerations

The following limitations and considerations are currently known:

- Order signing via the Polymarket Python client is slow, taking more than 1 second.
- Post-only orders are not supported.
- Reduce-only orders are not supported.

## Reconciliation

The Polymarket API returns either all active (open) orders or specific orders when queried by their
Polymarket order ID (`venue_order_id`). During reconciliation, order reports are obtained for:

- All instruments with active (open) orders, as reported by Polymarket.
- All open orders according to Nautilus execution state.

Since the Polymarket API does not natively support positions, they are inferred from user trades.

## WebSockets

The `PolymarketWebSocketClient` is built on top of the high-performance Nautilus `WebSocketClient` base class, written in Rust.

### Data

The main data WebSocket handles all `market` channel subscriptions received during the initial
connection sequence, up to `ws_connection_delay_secs`. For any additional subscriptions, a new `PolymarketWebSocketClient` is
created for each new instrument (asset).

### Execution

The main execution WebSocket manages all `user` channel subscriptions based on the Polymarket instruments
available in the cache during the initial connection sequence. When trading commands are issued for additional instruments,
a separate `PolymarketWebSocketClient` is created for each new instrument (asset).

:::note
Polymarket does not support unsubscribing from channel streams once subscribed.
:::