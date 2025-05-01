require("dotenv").config();
const { privateKeyToAccount } = require("viem/accounts");
const hl = require("@nktkas/hyperliquid");

(async () => {
  const PRIVATE_KEY = process.env.PRIVATE_KEY;
  if (!PRIVATE_KEY) {
    console.error("Error: PRIVATE_KEY not set in .env file.");
    process.exit(1);
  }

  // Ensure private key is properly formatted
  const formattedKey = PRIVATE_KEY.startsWith("0x")
    ? PRIVATE_KEY
    : `0x${PRIVATE_KEY}`;
  console.log(
    `Private key formatted: ${formattedKey.substring(
      0,
      6
    )}...${formattedKey.substring(formattedKey.length - 4)}`
  );

  // Create account and display address
  const account = privateKeyToAccount(formattedKey);
  console.log(`Using address: ${account.address}`);

  // Expected address
  const expectedAddress = "0x5aD3f8df47656AA57Ca047d7f5bD69d2E32B8F04";
  console.log(
    `Is using expected address: ${
      account.address.toLowerCase() === expectedAddress.toLowerCase()
    }`
  );

  // Create transport and client
  const transport = new hl.HttpTransport({ isTestnet: true });
  console.log("Created HTTP transport for testnet");

  const client = new hl.WalletClient({ wallet: account, transport });
  console.log("Created wallet client");

  try {
    console.log("Attempting to enable big blocks...");
    const response = await client.evmUserModify({ usingBigBlocks: true });
    console.log("Big blocks enabled:", response);
  } catch (error) {
    console.error("Failed to enable big blocks:", error.response || error);

    // Check if the error contains information about the wallet
    if (
      error.response &&
      error.response.response
    ) {
      console.error("Error response:", error.response.response);
    }
  }
})();
