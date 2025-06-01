import * as hl from "@nktkas/hyperliquid";
import { privateKeyToAccount } from "viem/accounts";

const wallet = privateKeyToAccount("0x..."); // Replace with your private key
const transport = new hl.HttpTransport();
const client = new hl.WalletClient({ wallet, transport });

const result = await client.sendAction({
  type: "evmUserModify",
  usingBigBlocks: true,
});
