# Liquidity Hook

This guide will walk you through the necessary steps to add your Liquidity Hook into INIT's frontend. Please follow these instructions carefully to ensure a smooth integration process.

## Prerequisites

Before you can submit your Liquidity Hook, please ensure you have completed the following steps:

1. **Liquidity Hook Contract Integration:** Your Liquidity Hook contract must be fully implemented and deployed on-chain. [Docs](https://dev.init.capital/)
2. **Verify Contract Code:** Ensure that the contract code is verified on the block explorer of the integrated chain. This can be done on platforms like [Mantle Explorer](https://explorer.mantle.xyz/) or [Blastscan](https://blastscan.io), depending on the chain you are using.
3. **Working Frontend:** You must have a working frontend application that is connected to your deployed hooks. This ensures that users can interact with your Liquidity Hook as intended.

## How to Submit Your Liquidity Hook

To submit your Liquidity Hook for integration, you will need to open a Pull Request (PR) with the necessary information. Here is a step-by-step guide on what to do:

1. **Fork this repo**: Fork this repo to your account/org.
2. **Provide Required Information:** Navigate to the `hooks.json` file. This JSON file contains a list of hooks grouped by ChainID. In the changes, you must include a JSON object with the following structure and data in the correct ChainID where your hooks are live:

```
Available Chains:
- Mantle (ChainID: 5000)
- Blast (ChainID: 81457)
```

```JSON
JSON structure:

{
  "id": "<chainID>-<protocol>-<hookName> (Use camelCase)",
  "name": "Name of the Hook",
  "protocol": "Protocol Name",
  "url": "URL of the interface where user can use the hook",
  "contractAddress": "Hook Contract address",
  "logoUrl": "URL to the logo image for the hook",
  "type": "Choose one: LOOPING | MARGIN_TRADING | LEVERAGED_YIELD_FARMING | VAULT | YIELD_STRATEGY",
  "supportedAssets": ["List of the supported asset addresses"],
  "description": "Description of how the hook works",
  "apyEndpoint": "Optional: The endpoint of the APY of the hook",
  "fee": "Optional: If the hook has a fee, specify it here (BPS)"
}
```

3. **Open a PR:** Open the PR using "Compare Across Fork" to propose your changes.
4. **Wait for Approval:** After submitting your PR, please wait for our team to review it. We may request changes or additional information. Once your PR is approved and merged, your Liquidity Hook will be shown on INIT's frontend.

Thank you for contributing to our project and enhancing INIT's ecosystem with your Liquidity Hook!
