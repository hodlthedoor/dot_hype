#!/usr/bin/env node
const fs = require("fs");
const readline = require("readline");

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

// Function to update .env file
function updateEnvFile(updates) {
  try {
    // Read existing .env file or create a new one
    let envContents = "";
    if (fs.existsSync(".env")) {
      envContents = fs.readFileSync(".env", "utf8");
    }

    // Parse existing variables into a map
    const envVars = {};
    envContents.split("\n").forEach((line) => {
      if (line.trim() && !line.startsWith("#")) {
        const [key, value] = line.split("=");
        if (key && value) {
          envVars[key.trim()] = value.trim();
        }
      }
    });

    // Update with new values
    Object.keys(updates).forEach((key) => {
      envVars[key] = updates[key];
    });

    // Convert back to string
    const newEnvContents = Object.entries(envVars)
      .map(([key, value]) => `${key}=${value}`)
      .join("\n");

    // Write back to .env
    fs.writeFileSync(".env", newEnvContents);
    console.log("✅ .env file updated successfully!");
  } catch (error) {
    console.error("Error updating .env file:", error);
  }
}

console.log("🚀 DotHype Contract Address Updater");
console.log("Enter the deployed contract addresses (leave blank to skip):\n");

// Ask for each address
rl.question("Registry Address: ", (REGISTRY_ADDRESS) => {
  rl.question("Controller Address: ", (CONTROLLER_ADDRESS) => {
    rl.question("Metadata Address: ", (METADATA_ADDRESS) => {
      rl.question("Resolver Address: ", (RESOLVER_ADDRESS) => {
        rl.question("MockOracle Address: ", (MOCK_ORACLE_ADDRESS) => {
          // Prepare updates (only include non-empty values)
          const updates = {};
          if (REGISTRY_ADDRESS) updates.REGISTRY_ADDRESS = REGISTRY_ADDRESS;
          if (CONTROLLER_ADDRESS)
            updates.CONTROLLER_ADDRESS = CONTROLLER_ADDRESS;
          if (METADATA_ADDRESS) updates.METADATA_ADDRESS = METADATA_ADDRESS;
          if (RESOLVER_ADDRESS) updates.RESOLVER_ADDRESS = RESOLVER_ADDRESS;
          if (MOCK_ORACLE_ADDRESS)
            updates.MOCK_ORACLE_ADDRESS = MOCK_ORACLE_ADDRESS;

          // Update .env file
          updateEnvFile(updates);

          // Display summary
          console.log("\n📝 Summary of addresses:");
          Object.entries(updates).forEach(([key, value]) => {
            console.log(`${key}=${value}`);
          });

          rl.close();
        });
      });
    });
  });
});
