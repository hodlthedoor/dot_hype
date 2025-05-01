require("dotenv").config();
const { privateKeyToAccount } = require("viem/accounts");

(async () => {
  const PRIVATE_KEY = process.env.PRIVATE_KEY;
  if (!PRIVATE_KEY) {
    console.error("Error: PRIVATE_KEY not set in .env file.");
    process.exit(1);
  }

  try {
    // Log the private key with some obfuscation for security
    const visiblePart =
      PRIVATE_KEY.substring(0, 6) +
      "..." +
      PRIVATE_KEY.substring(PRIVATE_KEY.length - 4);
    console.log(`Using private key starting with: ${visiblePart}`);

    // Convert to account and get address
    const account = privateKeyToAccount(`${PRIVATE_KEY}`);
    console.log(`Derived address: ${account.address}`);

    // Expected address
    const expectedAddress = "0x5aD3f8df47656AA57Ca047d7f5bD69d2E32B8F04";
    console.log(`Expected address: ${expectedAddress}`);

    // Compare
    if (account.address.toLowerCase() === expectedAddress.toLowerCase()) {
      console.log("✅ Addresses match!");
    } else {
      console.log("❌ Addresses do not match!");
    }
  } catch (error) {
    console.error("Error processing private key:", error);
  }
})();
