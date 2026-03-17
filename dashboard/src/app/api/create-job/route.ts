import { NextResponse } from "next/server";
import { createWalletClient, http, keccak256, stringToHex, parseEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { baseSepolia } from "viem/chains";
import { jobMarketplaceAbi } from "@/lib/contracts";

const RPC_URL = process.env.NEXT_PUBLIC_RPC_URL!;
const JOB_MARKETPLACE_ADDRESS =
  process.env.NEXT_PUBLIC_JOB_MARKETPLACE_ADDRESS as `0x${string}`;
const HUMAN_PK = process.env.HUMAN_PK as `0x${string}`;

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const { specURI, rewardEth, deadlineHours } = body;

    if (!specURI || typeof specURI !== "string") {
      return NextResponse.json({
        success: false,
        error: "specURI is required",
      });
    }

    if (!HUMAN_PK) {
      return NextResponse.json({
        success: false,
        error: "HUMAN_PK is not configured",
      });
    }

    const rewardWei = parseEther(String(rewardEth || "0.0001"));
    const deadline = BigInt(
      Math.floor(Date.now() / 1000) + Number(deadlineHours || 24) * 3600
    );

    const account = privateKeyToAccount(HUMAN_PK);

    const client = createWalletClient({
      account,
      chain: baseSepolia,
      transport: http(RPC_URL),
    });

    const hash = await client.writeContract({
      address: JOB_MARKETPLACE_ADDRESS,
      abi: jobMarketplaceAbi,
      functionName: "createJob",
      args: [
        keccak256(stringToHex("eth_market_report")),
        specURI,
        rewardWei,
        deadline,
      ],
      value: rewardWei,
      account,
      chain: baseSepolia,
    });

    return NextResponse.json({
      success: true,
      txHash: hash,
    });
  } catch (err) {
    console.error("create-job error:", err);
    return NextResponse.json({
      success: false,
      error: err instanceof Error ? err.message : "Unknown create job error",
    });
  }
}