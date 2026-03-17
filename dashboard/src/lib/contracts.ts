import { createPublicClient, http, getAddress } from "viem";
import { foundry } from "viem/chains";

export const RPC_URL =
  process.env.NEXT_PUBLIC_RPC_URL || "http://127.0.0.1:8545";

export const JOB_MARKETPLACE_ADDRESS = getAddress(
  process.env.NEXT_PUBLIC_JOB_MARKETPLACE_ADDRESS ||
    "0x66Db6d191cd163F56197b767928A507dF8b47AA7"
);

export const AGENT_DIRECTORY_ADDRESS = getAddress(
  process.env.NEXT_PUBLIC_AGENT_DIRECTORY_ADDRESS ||
    "0x82B769500E34362a76DF81150e12C746093D954F"
);

export const ESCROW_BOND_ADDRESS = getAddress(
  process.env.NEXT_PUBLIC_ESCROW_BOND_ADDRESS ||
    "0x7ef8E99980Da5bcEDcF7C10f41E55f759F6A174B"
);

export const publicClient = createPublicClient({
  chain: foundry,
  transport: http(RPC_URL),
});

export const jobMarketplaceAbi = [
  {
    type: "function",
    name: "nextJobId",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "jobs",
    stateMutability: "view",
    inputs: [{ name: "", type: "uint256" }],
    outputs: [
      { name: "id", type: "uint256" },
      { name: "parentJobId", type: "uint256" },
      { name: "creator", type: "address" },
      { name: "assignedAgent", type: "address" },
      { name: "preferredAgent", type: "address" },
      { name: "category", type: "bytes32" },
      { name: "specURI", type: "string" },
      { name: "resultURI", type: "string" },
      { name: "rewardWei", type: "uint96" },
      { name: "bondWeiRequired", type: "uint96" },
      { name: "deadline", type: "uint64" },
      { name: "status", type: "uint8" },
      { name: "isSubtask", type: "bool" },
    ],
  },
  {
    type: "function",
    name: "getChildJobs",
    stateMutability: "view",
    inputs: [{ name: "parentJobId", type: "uint256" }],
    outputs: [{ name: "", type: "uint256[]" }],
  },
  {
    type: "function",
    name: "markCompleted",
    stateMutability: "nonpayable",
    inputs: [{ name: "jobId", type: "uint256" }],
    outputs: [],
  },
  {
    type: "function",
    name: "createJob",
    stateMutability: "payable",
    inputs: [
      { name: "category", type: "bytes32" },
      { name: "specURI", type: "string" },
      { name: "rewardWei", type: "uint96" },
      { name: "deadline", type: "uint64" },
    ],
    outputs: [{ name: "jobId", type: "uint256" }],
  },
] as const;

export const agentDirectoryAbi = [
  {
    type: "function",
    name: "getTrustStats",
    stateMutability: "view",
    inputs: [{ name: "agentWallet", type: "address" }],
    outputs: [
      {
        type: "tuple",
        components: [
          { name: "bondedJobsCompleted", type: "uint32" },
          { name: "bondedJobsFailed", type: "uint32" },
          { name: "reputationScore", type: "uint32" },
        ],
      },
    ],
  },
  {
    type: "function",
    name: "getBondBps",
    stateMutability: "view",
    inputs: [{ name: "agentWallet", type: "address" }],
    outputs: [{ name: "", type: "uint16" }],
  },
] as const;

export const escrowBondAbi = [
  {
    type: "function",
    name: "bonds",
    stateMutability: "view",
    inputs: [{ name: "", type: "uint256" }],
    outputs: [
      { name: "bondedAgent", type: "address" },
      { name: "amountWei", type: "uint96" },
      { name: "posted", type: "bool" },
      { name: "settled", type: "bool" },
    ],
  },
  {
    type: "function",
    name: "rewards",
    stateMutability: "view",
    inputs: [{ name: "", type: "uint256" }],
    outputs: [
      { name: "amountWei", type: "uint96" },
      { name: "funded", type: "bool" },
      { name: "released", type: "bool" },
      { name: "refunded", type: "bool" },
    ],
  },
] as const;

export type UiJob = {
  id: number;
  parentJobId: number;
  creator: `0x${string}`;
  assignedAgent: `0x${string}`;
  preferredAgent: `0x${string}`;
  category: `0x${string}`;
  specURI: string;
  resultURI: string;
  rewardWei: string;
  bondWeiRequired: string;
  deadline: number;
  status: number;
  isSubtask: boolean;
  childJobs?: number[];
  txHashes?: Record<string, string>;
};

export async function fetchAllJobs(): Promise<UiJob[]> {
  const nextJobId = await publicClient.readContract({
    address: JOB_MARKETPLACE_ADDRESS,
    abi: jobMarketplaceAbi,
    functionName: "nextJobId",
  });

  const jobs: UiJob[] = [];

  for (let id = 1n; id < nextJobId; id++) {
    const raw = await publicClient.readContract({
      address: JOB_MARKETPLACE_ADDRESS,
      abi: jobMarketplaceAbi,
      functionName: "jobs",
      args: [id],
    });

    const childIds = !raw[12]
      ? await publicClient.readContract({
          address: JOB_MARKETPLACE_ADDRESS,
          abi: jobMarketplaceAbi,
          functionName: "getChildJobs",
          args: [id],
        })
      : [];

    jobs.push({
      id: Number(raw[0]),
      parentJobId: Number(raw[1]),
      creator: raw[2],
      assignedAgent: raw[3],
      preferredAgent: raw[4],
      category: raw[5],
      specURI: raw[6],
      resultURI: raw[7],
      rewardWei: raw[8].toString(),
      bondWeiRequired: raw[9].toString(),
      deadline: Number(raw[10]),
      status: Number(raw[11]),
      isSubtask: raw[12],
      childJobs: childIds.map((x) => Number(x)),
      txHashes: {},
    });
  }

  return jobs;
}

export async function fetchAgentStats(agent: `0x${string}`) {
  const stats = await publicClient.readContract({
    address: AGENT_DIRECTORY_ADDRESS,
    abi: agentDirectoryAbi,
    functionName: "getTrustStats",
    args: [agent],
  });

  let bondBps = 0;
  try {
    bondBps = await publicClient.readContract({
      address: AGENT_DIRECTORY_ADDRESS,
      abi: agentDirectoryAbi,
      functionName: "getBondBps",
      args: [agent],
    });
  } catch {
    bondBps = 0;
  }

  return {
    bondedJobsCompleted: Number(stats.bondedJobsCompleted),
    bondedJobsFailed: Number(stats.bondedJobsFailed),
    reputationScore: Number(stats.reputationScore),
    bondBps: Number(bondBps),
  };
}