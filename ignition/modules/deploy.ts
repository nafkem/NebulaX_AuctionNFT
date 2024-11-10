

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const NebulaXModule = buildModule("NebulaXModule", (m: any) => {
 
  // Deploy LanSeller with token address and price feed
  const nebXToken = m.contract("NebXToken");
  //const verifier = m.contract("Verifier");
  const nebulaX = m.contract("NebulaX", [nebXToken]);

  return { nebXToken,nebulaX };
});

export default NebulaXModule;