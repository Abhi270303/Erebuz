# Repos — fusionx-v3 (Phase 2)

| repo | default branch | audited commit/tag | core source path | language |
|------|----------------|--------------------|------------------|----------|
| https://github.com/fusionx-finance/fusionx-v3-core | main | source/repo/v3-core | contracts/ | Solidity |
| https://github.com/fusionx-finance/fusionx-v3-periphery | main | source/repo/v3-periphery | contracts/ | Solidity |
| https://github.com/fusionx-finance/fusionx-v3-lm-pool | main | source/repo/v3-lm-pool | contracts/ | Solidity |
| https://github.com/fusionx-finance/fusionx-lbp-masterchef-v3 | main | source/repo/lbp-masterchef-v3 | contracts/ | Solidity |
| https://github.com/fusionx-finance/fusionx-router | main | source/repo/router | contracts/ | Solidity |
| https://github.com/fusionx-finance/fusionx-ifo | main | source/repo/ifo | contracts/ | Solidity |

## Mismatch vs deployed addresses?
- MasterChef (deployed 0xF6efaDb0fD3504EE1d55A3c35a8C5755aE78044e) source is in lbp-masterchef-v3
- Core pools deployed via factory at known Mantle addresses
- No diff analysis performed against deployed bytecode — see deployed-vs-audited.md
