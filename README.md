# GODS OF IMD: contracts

The on-chain side of [GODS OF IMD](https://gods.getnightshift.tech), a living NFT world judged by the IMD Oracle.

| Contract | File | What it does |
| --- | --- | --- |
| `GodsOfIMDInhabitants` | `src/GodsOfIMDInhabitants.sol` | ERC-721 "GODS OF IMD Inhabitants" (`SOUL`), with ERC-4906 metadata events and an ERC-2981 royalty. Genesis is 1,000 souls, fixed in the contract. Each soul draws one Mark from a fixed deck (640 Mortal, 250 Blessed, 100 Ascended, 10 Divine) from the hash of the block after its forge. |
| `OracleShrine` | `src/OracleShrine.sol` | The game's treasury and altar. It holds IMD, buys Oracle questions from IMD's Intake, verifies the signed EIP-712 attestations on chain, records the God's judgments and the daily world anchors, and runs the weekly rewards vault. |

## Deploying

Both constructors take addresses only, so IMD's launch (`launch.open` with `onchain: "evm_contracts"`) can deploy them as they are, the shrine first:

```
OracleShrine(address owner_, IIntake intake_, IERC20 imd_, address oracleSigner_, address director_)
GodsOfIMDInhabitants(address owner_, IERC20 imd_, address shrine_, address burnSink_)
```

The launch manifest has this shape (the IMD token, the game server's wallet and the burn sink depend on the chain):

```json
{
  "kind": "evm_contracts",
  "contracts": [
    { "contract": "OracleShrine", "constructorArgs": ["$owner", "<IMD Intake v2>", "<IMD token>", "<IMD oracle signer>", "<game server wallet>"] },
    { "contract": "GodsOfIMDInhabitants", "constructorArgs": ["$owner", "<IMD token>", "$contract:OracleShrine", "<burn sink>"] }
  ]
}
```

- IMD Intake v2: `0xa43e6f75ee006411f79ac1c84120606c2330de82` (every chain). IMD's oracle signer: `0x5598aa9146215bc13eb26f2c692ad1461fd32982`.
- IMD token: `0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7` on Ethereum, `0x5f7bb59365ce557c26dbcaa4ee9d39a4b95b7127` on Robinhood Chain, `0x56bcf2a5f47710649a4091219ef0b56e2d1b58bf` (imdTEST) on Sepolia.
- The constructors only reject zero addresses and make no external call. Nothing is called after deployment; the owner then sets the metadata URL (`setBaseURI`), the steward (`setSteward`), the payees (`setPayees`) and the mint phase (`setPhase`).

## Build and test

```sh
forge build
forge test
```

Solidity 0.8.30, optimizer 200 runs, EVM `cancun`, `bytecode_hash = "none"`.

## Libraries

Vendored as plain files in `lib/`, so the repository builds offline:

- `lib/openzeppelin-contracts`: OpenZeppelin Contracts 5.6.1 (MIT), the `.sol` sources of the npm package.
- `lib/forge-std`: forge-std 1.11.0 (MIT or Apache-2.0), used by the tests only.

## License

MIT. See `LICENSE`.
