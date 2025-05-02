// Script to generate merkle tree and proofs for testing
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");
const ethers = require("ethers");

function generateMerkleTree(addresses) {
  // Convert addresses to leaf nodes exactly as the contract does
  const leafNodes = addresses.map((addr) =>
    keccak256(ethers.utils.solidityPack(["address"], [addr]))
  );

  // Create merkle tree
  const merkleTree = new MerkleTree(leafNodes, keccak256, {
    sortPairs: true, // Sort pairs before hashing (important for Solidity verification)
  });

  return { merkleTree, leafNodes };
}

function generateProof(merkleTree, leafNode) {
  return merkleTree.getHexProof(leafNode);
}

// Main function to generate and output merkle data for tests
function generateMerkleData() {
  // Example addresses for testing (matching the test contract addresses)
  const addresses = [
    "0x0000000000000000000000000000000000000003", // user1
    "0x0000000000000000000000000000000000000004", // user2
    "0x0000000000000000000000000000000000000005", // user3
  ];

  // Generate merkle tree
  const { merkleTree, leafNodes } = generateMerkleTree(addresses);

  // Get merkle root
  const merkleRoot = merkleTree.getHexRoot();

  // Generate proofs for each address
  const proofs = {};
  for (let i = 0; i < addresses.length; i++) {
    proofs[addresses[i]] = generateProof(merkleTree, leafNodes[i]);
  }

  // Output results
  console.log("Merkle Root:", merkleRoot);
  console.log("\nSolidity Code for Tests:");
  console.log(`\nbytes32 public merkleRoot = ${merkleRoot};`);

  for (let i = 0; i < addresses.length; i++) {
    const addr = addresses[i];
    const addrName = `user${i + 1}`;

    console.log(`\n// Proof for ${addrName} (${addr})`);
    console.log(
      `bytes32[] memory ${addrName}Proof = new bytes32[](${proofs[addr].length});`
    );

    for (let j = 0; j < proofs[addr].length; j++) {
      console.log(`${addrName}Proof[${j}] = ${proofs[addr][j]};`);
    }

    console.log(`proofs[${addrName}] = ${addrName}Proof;`);
  }

  console.log("\nVerification Example:");
  console.log(`// In Solidity, the leaf would be computed as:`);
  console.log(`// bytes32 leaf = keccak256(abi.encodePacked(userAddress));`);
  console.log("\n// In JavaScript, to check if user1 is in the tree:");
  console.log(
    `const leaf = keccak256(ethers.utils.solidityPack(['address'], ['${addresses[0]}']));`
  );
  console.log(`const proof = ${JSON.stringify(proofs[addresses[0]])};`);
  console.log(
    `const isValid = merkleTree.verify(proof, leaf, merkleRoot); // Should be true`
  );

  // Log leaf values for debugging
  console.log("\nDebug information:");
  for (let i = 0; i < addresses.length; i++) {
    const addr = addresses[i];
    const leaf = keccak256(
      ethers.utils.solidityPack(["address"], [addr])
    ).toString("hex");
    console.log(`Leaf for ${addr}: 0x${leaf}`);
  }
}

// Run the generator
generateMerkleData();
