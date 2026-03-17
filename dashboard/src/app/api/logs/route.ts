import { NextRequest, NextResponse } from "next/server";
import fs from "fs";
import path from "path";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type StoredLogEntry = {
  role: string;
  action: string;
  details?: Record<string, unknown>;
  tx_hash?: string;
  step?: number;
  timestamp: number;
};

type StoredLogs = {
  entries: StoredLogEntry[];
};

const DATA_DIR = path.join(process.cwd(), "data");
const LOG_FILE = path.join(DATA_DIR, "agent_logs.json");

function ensureStore() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }

  if (!fs.existsSync(LOG_FILE)) {
    fs.writeFileSync(LOG_FILE, JSON.stringify({ entries: [] }, null, 2));
  }
}

function readStore(): StoredLogs {
  ensureStore();
  const raw = fs.readFileSync(LOG_FILE, "utf8");
  return JSON.parse(raw) as StoredLogs;
}

function writeStore(data: StoredLogs) {
  ensureStore();
  fs.writeFileSync(LOG_FILE, JSON.stringify(data, null, 2));
}

export async function GET() {
  try {
    const store = readStore();

    const grouped = ["main", "price", "volume", "yield"].map((role) => ({
      key: role,
      label:
        role === "main"
          ? "MainContractor"
          : role === "price"
          ? "PriceScout"
          : role === "volume"
          ? "VolumeScout"
          : "YieldScout",
      data: {
        status: "running",
        steps: store.entries.filter((e) => e.role === role).slice(-20),
      },
    }));

    return NextResponse.json({
      success: true,
      logs: grouped,
    });
  } catch (err) {
    console.error(err);
    return NextResponse.json({
      success: false,
      error: err instanceof Error ? err.message : "Unknown logs error",
    });
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();

    const entry: StoredLogEntry = {
      role: body.role,
      action: body.action,
      details: body.details || {},
      tx_hash: body.tx_hash,
      step: body.step,
      timestamp: body.timestamp || Date.now(),
    };

    if (!entry.role || !entry.action) {
      return NextResponse.json(
        { success: false, error: "role and action are required" },
        { status: 400 }
      );
    }

    const store = readStore();
    store.entries.push(entry);

    // keep only the most recent 500 entries
    if (store.entries.length > 500) {
      store.entries = store.entries.slice(-500);
    }

    writeStore(store);

    return NextResponse.json({ success: true });
  } catch (err) {
    console.error(err);
    return NextResponse.json({
      success: false,
      error: err instanceof Error ? err.message : "Unknown log ingest error",
    });
  }
}