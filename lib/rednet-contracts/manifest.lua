return {
  manifest_version = 1,
  type = "library",
  name = "rednet_contracts",
  version = "0.1.0",
  source_base = "https://raw.githubusercontent.com/wradley/cc-tweaked-libraries/refs/heads/main/lib/rednet-contracts",
  source_prefix = "src",
  files = {
    "src/rednet_contracts/init.lua",
    "src/rednet_contracts/discovery_v1.lua",
    "src/rednet_contracts/errors.lua",
    "src/rednet_contracts/mrpc_v1.lua",
    "src/rednet_contracts/schema_validation.lua",
    "src/rednet_contracts/services/global_inventory_v1.lua",
    "src/rednet_contracts/services/warehouse_v1.lua",
  },
  deps = {},
}
