"use client";

import { fetchAllJobs, fetchAgentStats, type UiJob } from "@/lib/contracts";

import React, { useEffect, useMemo, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Separator } from "@/components/ui/separator";
import { Activity, CheckCircle2, Clock3, Shield, Wallet, AlertTriangle, RefreshCcw, FileText, Link2 } from "lucide-react";

const STATUS = {
  0: "None",
  1: "Open",
  2: "Accepted",
  3: "Submitted",
  4: "Completed",
  5: "Failed",
  6: "Cancelled",
};

const statusTone = {
  None: "secondary",
  Open: "secondary",
  Accepted: "default",
  Submitted: "secondary",
  Completed: "default",
  Failed: "destructive",
  Cancelled: "destructive",
};

const short = (value?: string | null) => {
  if (!value) return "—";
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
};

const prettyEth = (wei?: string | number | bigint | null) => {
  if (wei == null) return "—";
  const eth = Number(wei) / 1e18;
  return `${eth.toFixed(6)} ETH`;
};


function getReputationTier(score: number) {
  if (score >= 100) return "Tier 3";
  if (score >= 25) return "Tier 2";
  if (score > 0) return "Tier 1";
  return "Unproven";
}

function getBondTierLabel(bondBps: number | undefined, reputationScore: number) {
  if (reputationScore === 0) return "High Bond";
  if (bondBps === undefined) return "Unknown";

  if (bondBps <= 500) return "Low Bond";
  if (bondBps <= 1000) return "Reduced Bond";
  if (bondBps <= 2000) return "Medium Bond";

  return "High Bond";
}


function getTimelineState(parent: UiJob | undefined, children: UiJob[]) {
  if (!parent) return [];

  const totalChildren = children.length;

  const acceptedChildren = children.filter(
    (c) =>
      c.assignedAgent &&
      c.assignedAgent !== "0x0000000000000000000000000000000000000000"
  ).length;

  const submittedChildren = children.filter(
    (c) => c.resultURI && c.resultURI.length > 0
  ).length;

  const completedChildren = children.filter((c) => c.status === 4).length;

  const subtasksCreated = totalChildren > 0;
  const finalSubmitted = !!(parent.resultURI && parent.resultURI.length > 0);
  const humanApproved = parent.status === 4;

  const stageState = (count: number, total: number) => {
    if (total === 0 || count === 0) return "pending";
    if (count < total) return "in_progress";
    return "complete";
  };

  return [
    { label: "Job Created", state: "complete" },
    {
      label: "Main Agent Accepted",
      state: parent.status >= 2 ? "complete" : "pending",
    },
    {
      label: "Subtasks Spawned",
      state: subtasksCreated ? "complete" : "pending",
      detail: totalChildren > 0 ? `${totalChildren} created` : undefined,
    },
    {
      label: "Specialists Accepted",
      state: stageState(acceptedChildren, totalChildren),
      detail:
        totalChildren > 0 ? `${acceptedChildren}/${totalChildren} accepted` : undefined,
    },
    {
      label: "Results Submitted",
      state: stageState(submittedChildren, totalChildren),
      detail:
        totalChildren > 0 ? `${submittedChildren}/${totalChildren} submitted` : undefined,
    },
    {
      label: "Subtasks Completed",
      state: stageState(completedChildren, totalChildren),
      detail:
        totalChildren > 0 ? `${completedChildren}/${totalChildren} completed` : undefined,
    },
    {
      label: "Final Report Submitted",
      state: finalSubmitted ? "complete" : "pending",
    },
    {
      label: "Human Approved",
      state: humanApproved ? "complete" : "pending",
    },
  ];
}



const isPendingHumanApproval = (job: any) =>
  !!job && !job.isSubtask && job.status === 3;

const isParentCompleted = (job: any) =>
  !!job && !job.isSubtask && job.status === 4;


const categoryLabel = (hex?: string | null) => {
  const map: Record<string, string> = {
    "0xb635b0ee6e4c15c18d1b36f84d92442e53da477ae300027dd06478d4ee0559db": "eth_market_report",
    "0x6af8d57439ffc95a5893d7485897e6bc79cda8d8f7ad59da55f23c3028406a38": "price_data",
    "0x6a5a6bbc61eee87da7722fbf47558e3abfb4f2f0de82cb61196beacea7683270": "volume_data",
    "0x89a06dff28f52cee41ea301afe84fa01147a3d9eb01357854221a525ccacf0ea": "yield_data",
  };

  if (!hex) return "unknown";
  return map[hex.toLowerCase()] || short(hex);
};

const demoJobs = [
  {
    id: 5,
    parentJobId: 0,
    creator: "0x1111111111111111111111111111111111111111",
    assignedAgent: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
    preferredAgent: "0x0000000000000000000000000000000000000000",
    category: "0xb635b0ee6e4c15c18d1b36f84d92442e53da477ae300027dd06478d4ee0559db",
    specURI: "ipfs://new-report",
    resultURI: "ipfs://final-report",
    rewardWei: "1000000000000000000",
    bondWeiRequired: "0",
    deadline: Math.floor(Date.now() / 1000) + 3600,
    status: 3,
    isSubtask: false,
    childJobs: [6, 7, 8],
    txHashes: {
      created: "0xcreateparent",
      accepted: "0xacceptparent",
      submitted: "0xsubmitparent",
    },
  },
  {
    id: 6,
    parentJobId: 5,
    creator: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
    assignedAgent: "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
    preferredAgent: "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
    category: "0x6af8d57439ffc95a5893d7485897e6bc79cda8d8f7ad59da55f23c3028406a38",
    specURI: "ipfs://price-task",
    resultURI: "ipfs://price-result",
    rewardWei: "200000000000000000",
    bondWeiRequired: "40000000000000000",
    deadline: Math.floor(Date.now() / 1000) + 1800,
    status: 4,
    isSubtask: true,
    txHashes: {
      accepted: "0xacceptprice",
      submitted: "0xsubmitprice",
      completed: "0xcompleteprice",
    },
  },
  {
    id: 7,
    parentJobId: 5,
    creator: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
    assignedAgent: "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65",
    preferredAgent: "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65",
    category: "0x6a5a6bbc61eee87da7722fbf47558e3abfb4f2f0de82cb61196beacea7683270",
    specURI: "ipfs://volume-task",
    resultURI: "ipfs://volume-result",
    rewardWei: "200000000000000000",
    bondWeiRequired: "40000000000000000",
    deadline: Math.floor(Date.now() / 1000) + 1800,
    status: 4,
    isSubtask: true,
    txHashes: {
      accepted: "0xacceptvolume",
      submitted: "0xsubmitvolume",
      completed: "0xcompletevolume",
    },
  },
  {
    id: 8,
    parentJobId: 5,
    creator: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
    assignedAgent: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
    preferredAgent: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
    category: "0x89a06dff28f52cee41ea301afe84fa01147a3d9eb01357854221a525ccacf0ea",
    specURI: "ipfs://yield-task",
    resultURI: "ipfs://yield-result",
    rewardWei: "200000000000000000",
    bondWeiRequired: "40000000000000000",
    deadline: Math.floor(Date.now() / 1000) + 1800,
    status: 4,
    isSubtask: true,
    txHashes: {
      accepted: "0xacceptyield",
      submitted: "0xsubmityield",
      completed: "0xcompleteyield",
    },
  },
];

const demoAgents = [
  { name: "MainContractor", address: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC", role: "main", reputation: 0, bondedCompleted: 0, bondTier: "No bond on parent jobs" },
  { name: "PriceScout", address: "0x90F79bf6EB2c4f870365E785982E1f101E93b906", role: "price", reputation: 10, bondedCompleted: 1, bondTier: "20%" },
  { name: "VolumeScout", address: "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65", role: "volume", reputation: 10, bondedCompleted: 1, bondTier: "20%" },
  { name: "YieldScout", address: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc", role: "yield", reputation: 10, bondedCompleted: 1, bondTier: "20%" },
];

function StatusBadge({ status }: { status: number }) {
  const label = STATUS[status] || "Unknown";
  return <Badge variant={statusTone[label] || "secondary"}>{label}</Badge>;
}

function TxRow({ label, hash }) {
  return (
    <div className="flex items-center justify-between gap-3 text-sm">
      <span className="text-muted-foreground">{label}</span>
      <code className="rounded bg-muted px-2 py-1 text-xs">{hash || "—"}</code>
    </div>
  );
}

export default function BondedAgentDashboard() {
  const [jobs, setJobs] = useState(demoJobs);
  const [isLive, setIsLive] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [selectedParentId, setSelectedParentId] = useState(5);

  const [rpcUrl] = useState(process.env.NEXT_PUBLIC_RPC_URL || "http://127.0.0.1:8545");
  const [marketplaceAddress] = useState(
    process.env.NEXT_PUBLIC_JOB_MARKETPLACE_ADDRESS || "0x66Db6d191cd163F56197b767928A507dF8b47AA7"
  );

  const [notice, setNotice] = useState("This is an MVP control panel. It is wired for the exact workflow you built: parent job creation, subtask delegation, specialist bonding, result submission, and manual human approval.");

  const [createSpecURI, setCreateSpecURI] = useState("ipfs://eth-market-job");
  const [createRewardEth, setCreateRewardEth] = useState("0.0001");
  const [createDeadlineHours, setCreateDeadlineHours] = useState("24");

  const [isCreating, setIsCreating] = useState(false);
  const [agentLogs, setAgentLogs] = useState<any[]>([]);
  const [logsLoading, setLogsLoading] = useState(false);

  const [agentStats, setAgentStats] = useState<Record<string, any>>({});

  const parentJobs = useMemo(() => jobs.filter((j) => !j.isSubtask), [jobs]);
  const selectedParent = useMemo(() => parentJobs.find((j) => j.id === selectedParentId) || parentJobs[0], [parentJobs, selectedParentId]);
  const selectedChildren = useMemo(() => jobs.filter((j) => j.parentJobId === selectedParent?.id), [jobs, selectedParent]);

  useEffect(() => {
    if (!selectedParent && parentJobs.length) setSelectedParentId(parentJobs[0].id);
  }, [parentJobs, selectedParent]);

  const refreshLiveData = async () => {
    try {
      setIsLoading(true);
      const liveJobs = await fetchAllJobs();

      if (liveJobs.length > 0) {
        setJobs(liveJobs);
        setIsLive(true);
        setNotice("Live on-chain state loaded from JobMarketplace.");
      } else {
        setNotice("Connected successfully, but no jobs were found on-chain. Showing demo data until a fresh job is created.");
      }
    } catch (error) {
      console.error(error);
      setNotice("Could not load live chain state. Showing demo data.");
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    refreshLiveData();
    refreshAgentLogs();
    refreshAgentStats();

    const timer = setInterval(() => {
      refreshLiveData();
      refreshAgentLogs();
      refreshAgentStats();
    }, 5000);

    return () => clearInterval(timer);
  }, []);


  const refreshAgentLogs = async () => {
    try {
      setLogsLoading(true);

      const res = await fetch("/api/logs");
      const data = await res.json();

      if (data.success) {
        setAgentLogs(data.logs || []);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLogsLoading(false);
    }
  };


  const refreshAgentStats = async () => {
    try {
      const statsEntries = await Promise.all(
        demoAgents.map(async (agent) => {
          try {
            const stats = await fetchAgentStats(agent.address as `0x${string}`);
            return [agent.address, stats];
          } catch (err) {
            console.error(`Failed to load stats for ${agent.address}`, err);
            return [agent.address, null];
          }
        })
      );

      setAgentStats(Object.fromEntries(statsEntries));
    } catch (err) {
      console.error(err);
    }
  };
  

  const createParentJob = async () => {
    try {
      setIsCreating(true);

      const res = await fetch("/api/create-job", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          specURI: createSpecURI,
          rewardEth: createRewardEth,
          deadlineHours: createDeadlineHours,
        }),
      });

      const data = await res.json();

      if (data.success) {
        setNotice(`Parent job created successfully. Tx: ${data.txHash}`);
        await refreshLiveData();
      } else {
        setNotice(`Create job failed: ${data.error || "Unknown error"}`);
      }
    } catch (err) {
      console.error(err);
      setNotice(`Create job error: ${err instanceof Error ? err.message : "Unknown error"}`);
    } finally {
      setIsCreating(false);
    }
  };


  const approveParent = async () => {
    if (!selectedParent) return;

    try {
      const res = await fetch("/api/approve", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ jobId: selectedParent.id }),
      });

      const data = await res.json();

      if (data.success) {
        setNotice(`Parent job ${selectedParent.id} approved. Tx: ${data.txHash}`);
        refreshLiveData();
      } else {
        setNotice(`Approval failed: ${data.error || "Unknown error"}`);
      }
    } catch (err) {
      console.error(err);
      setNotice(`Approval error: ${err instanceof Error ? err.message : "Unknown error"}`);
    }
  };

  const rejectParent = () => {
    setJobs((prev) => prev.map((job) => (job.id === selectedParent.id ? { ...job, status: 5 } : job)));
    setNotice(`Parent job ${selectedParent.id} rejected by human. In the real app, this button should call markFailed(${selectedParent.id}).`);
  };

  return (
    <div className="min-h-screen bg-background p-6">
      <div className="mx-auto grid max-w-7xl gap-6">
        <div className="grid gap-4 md:grid-cols-[1.2fr_0.8fr]">
          <Card className="rounded-2xl shadow-sm">
            <CardHeader>
              <div className="flex items-center justify-between gap-4">
                <div>
                  <CardTitle className="text-2xl">Bonded Agent Contractor</CardTitle>
                  <p className="mt-1 text-sm text-muted-foreground">
                    Human-controlled autonomous contractor dashboard with bonded specialists, scoped spending, and onchain settlement.
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <Badge variant="secondary" className="gap-2">
                    <Activity className="h-3.5 w-3.5" />
                    {isLive ? "Live Chain Data" : "Demo UI"}
                  </Badge>

                  <Button variant="outline" size="sm" onClick={refreshLiveData} className="gap-2">
                    <RefreshCcw className={`h-4 w-4 ${isLoading ? "animate-spin" : ""}`} />
                    Refresh
                  </Button>
                </div>
              </div>
            </CardHeader>
            <CardContent className="grid gap-4">
              <Alert>
                <Shield className="h-4 w-4" />
                <AlertTitle>Human stays in control</AlertTitle>
                <AlertDescription>{notice}</AlertDescription>
              </Alert>
              <div className="grid gap-3 md:grid-cols-3">
                <Card className="rounded-2xl">
                  <CardContent className="p-4">
                    <div className="text-xs text-muted-foreground">Parent jobs</div>
                    <div className="mt-2 text-2xl font-semibold">{parentJobs.length}</div>
                  </CardContent>
                </Card>
                <Card className="rounded-2xl">
                  <CardContent className="p-4">
                    <div className="text-xs text-muted-foreground">Subtasks</div>
                    <div className="mt-2 text-2xl font-semibold">{jobs.filter((j) => j.isSubtask).length}</div>
                  </CardContent>
                </Card>
                <Card className="rounded-2xl">
                  <CardContent className="p-4">
                    <div className="text-xs text-muted-foreground">Specialist bond size</div>
                    <div className="mt-2 text-2xl font-semibold">0.04 ETH</div>
                  </CardContent>
                </Card>
              </div>
            </CardContent>
          </Card>

          <div className="grid gap-4">
            <Card className="rounded-2xl shadow-sm">
              <CardHeader>
                <CardTitle className="text-lg">Create Parent Job</CardTitle>
              </CardHeader>
              <CardContent className="grid gap-3">
                <div className="grid gap-2">
                  <label className="text-sm font-medium">Spec URI</label>
                  <Input
                    value={createSpecURI}
                    onChange={(e) => setCreateSpecURI(e.target.value)}
                    placeholder="ipfs://new-report"
                  />
                </div>

                <div className="grid gap-2 sm:grid-cols-2">
                  <div className="grid gap-2">
                    <label className="text-sm font-medium">Reward (ETH)</label>
                    <Input
                      value={createRewardEth}
                      onChange={(e) => setCreateRewardEth(e.target.value)}
                      placeholder="1"
                    />
                  </div>

                  <div className="grid gap-2">
                    <label className="text-sm font-medium">Deadline (hours)</label>
                    <Input
                      value={createDeadlineHours}
                      onChange={(e) => setCreateDeadlineHours(e.target.value)}
                      placeholder="24"
                    />
                  </div>
                </div>

                <Button onClick={createParentJob} disabled={isCreating} className="gap-2">
                  <Wallet className="h-4 w-4" />
                  {isCreating ? "Creating..." : "Create Job"}
                </Button>

                <p className="text-xs text-muted-foreground">
                  This creates a top-level <code>eth_market_report</code> job using the human wallet configured on the server.
                </p>
              </CardContent>
            </Card>

            <Card className="rounded-2xl shadow-sm">
              <CardHeader>
                <div className="flex items-center justify-between gap-3">
                  <CardTitle className="text-lg">Manual Approval Panel</CardTitle>
                  {selectedParent && (
                    <StatusBadge status={selectedParent.status} />
                  )}
                </div>
              </CardHeader>
              <CardContent className="grid gap-3">




                <div className="rounded-xl border p-3 text-sm">
                  <div className="font-medium">Environment</div>
                  <div className="mt-2 text-muted-foreground break-all">
                    RPC: {rpcUrl}
                  </div>
                  <div className="mt-1 text-muted-foreground break-all">
                    Marketplace: {marketplaceAddress}
                  </div>
                  <div className="mt-1 text-muted-foreground">
                    Human signer is configured server-side.
                  </div>
                </div>




                <div className="grid gap-2 sm:grid-cols-2">
                  <Button onClick={approveParent} className="gap-2">
                    <CheckCircle2 className="h-4 w-4" />
                    Approve Final Report
                  </Button>

                  <Button variant="destructive" onClick={rejectParent} className="gap-2">
                    <AlertTriangle className="h-4 w-4" />
                    Reject / Fail Job
                  </Button>
                </div>

                <div className="grid gap-2">
                  {selectedParent && isPendingHumanApproval(selectedParent) && (
                    <div className="rounded-xl border border-amber-500/40 bg-amber-500/5 p-3 text-sm">
                      <div className="font-medium">Pending approval for parent job #{selectedParent.id}</div>
                      <div className="mt-1 text-muted-foreground">
                        Autonomous execution is complete. Funds remain gated until the human approves final settlement.
                      </div>
                    </div>
                  )}

                  {selectedParent && isParentCompleted(selectedParent) && (
                    <div className="rounded-xl border border-emerald-500/40 bg-emerald-500/5 p-3 text-sm">
                      <div className="font-medium">Parent job #{selectedParent.id} has been approved</div>
                      <div className="mt-1 text-muted-foreground">
                        Final settlement is complete. This is the final human sign-off step in the workflow.
                      </div>
                    </div>
                  )}

                  {!selectedParent && (
                    <div className="rounded-xl border p-3 text-sm text-muted-foreground">
                      Select a parent job to inspect its approval state.
                    </div>
                  )}

                  <p className="text-xs text-muted-foreground">
                    This is the human control point. Final settlement stays manual by design.
                  </p>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>



        <Tabs defaultValue="jobs" className="grid gap-4">
          <TabsList className="w-fit rounded-2xl">
            <TabsTrigger value="jobs">Jobs</TabsTrigger>
            <TabsTrigger value="agents">Agents</TabsTrigger>
            <TabsTrigger value="receipts">Receipts</TabsTrigger>
            <TabsTrigger value="logs">Logs</TabsTrigger>
          </TabsList>

          <TabsContent value="jobs" className="grid gap-4 lg:grid-cols-[0.9fr_1.1fr]">
            <Card className="rounded-2xl shadow-sm">
              <CardHeader>
                <CardTitle className="text-lg">Parent Jobs</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid gap-3">
                  {parentJobs.map((job) => (
                    <button
                      key={job.id}
                      onClick={() => setSelectedParentId(job.id)}
                      className={`rounded-2xl border p-4 text-left transition ${selectedParent?.id === job.id ? "border-primary shadow-sm" : "border-border"}`}
                    >
                      <div className="flex items-center justify-between gap-3">
                        <div>
                          <div className="font-medium">Job #{job.id}</div>
                          <div className="text-sm text-muted-foreground">{categoryLabel(job.category)}</div>
                        </div>
                        <StatusBadge status={job.status} />
                      </div>
                      <div className="mt-3 grid gap-1 text-sm text-muted-foreground">
                        <div>Reward: {prettyEth(job.rewardWei)}</div>
                        <div>Assigned: {short(job.assignedAgent)}</div>
                        <div>Result: {job.resultURI || "Pending"}</div>
                      </div>
                    </button>
                  ))}
                </div>
              </CardContent>
            </Card>

            <Card className="rounded-2xl shadow-sm">
              <CardHeader>
                <CardTitle className="text-lg">Selected Parent Job</CardTitle>
              </CardHeader>
              <CardContent className="grid gap-4">
                {selectedParent ? (
                  <>


                  {isPendingHumanApproval(selectedParent) && (
                    <Alert className="border-amber-500/40 bg-amber-500/5">
                      <Shield className="h-4 w-4" />
                      <AlertTitle>Human Approval Required</AlertTitle>
                      <AlertDescription>
                        The autonomous agents have completed the work and the parent job has been submitted.
                        Final settlement is paused until the human explicitly approves this job.
                      </AlertDescription>
                    </Alert>
                  )}

                  {isParentCompleted(selectedParent) && (
                    <Alert className="border-emerald-500/40 bg-emerald-500/5">
                      <CheckCircle2 className="h-4 w-4" />
                      <AlertTitle>Final Settlement Complete</AlertTitle>
                      <AlertDescription>
                        The human approved this parent job and final settlement has completed on-chain.
                      </AlertDescription>
                    </Alert>
                  )}


                    <div className="grid gap-3 md:grid-cols-2">
                      <Card className="rounded-2xl"><CardContent className="p-4"><div className="text-xs text-muted-foreground">Job ID</div><div className="mt-1 text-lg font-semibold">#{selectedParent.id}</div></CardContent></Card>
                      <Card className="rounded-2xl"><CardContent className="p-4"><div className="text-xs text-muted-foreground">Status</div><div className="mt-2"><StatusBadge status={selectedParent.status} /></div></CardContent></Card>
                      <Card className="rounded-2xl"><CardContent className="p-4"><div className="text-xs text-muted-foreground">Creator</div><div className="mt-1 text-sm font-medium">{short(selectedParent.creator)}</div></CardContent></Card>
                      <Card className="rounded-2xl"><CardContent className="p-4"><div className="text-xs text-muted-foreground">Assigned Main Agent</div><div className="mt-1 text-sm font-medium">{short(selectedParent.assignedAgent)}</div></CardContent></Card>
                    </div>

                    <Card className="rounded-2xl">
                      <CardHeader>
                        <CardTitle className="text-base">Job Timeline</CardTitle>
                      </CardHeader>

                      <CardContent>
                        <div className="grid gap-3">
                          {getTimelineState(selectedParent, selectedChildren).map((step, i) => {
                            const dotClass =
                              step.state === "complete"
                                ? "bg-emerald-500"
                                : step.state === "in_progress"
                                ? "bg-amber-400"
                                : "bg-muted";

                            const textClass =
                              step.state === "complete"
                                ? "font-medium"
                                : step.state === "in_progress"
                                ? "font-medium text-amber-700 dark:text-amber-400"
                                : "text-muted-foreground";

                            return (
                              <div key={i} className="flex items-center justify-between gap-3">
                                <div className="flex items-center gap-3">
                                  <div className={`h-3 w-3 rounded-full ${dotClass}`} />
                                  <div className={`text-sm ${textClass}`}>{step.label}</div>
                                </div>

                                {step.detail && (
                                  <div className="text-xs text-muted-foreground">{step.detail}</div>
                                )}
                              </div>
                            );
                          })}
                        </div>
                      </CardContent>
                    </Card>

                    <Card className="rounded-2xl">
                      <CardHeader>
                        <CardTitle className="text-base">Subtasks</CardTitle>
                      </CardHeader>
                      <CardContent className="grid gap-3">
                        {selectedChildren.map((child) => (
                          <div key={child.id} className="rounded-2xl border p-4">
                            <div className="flex items-center justify-between gap-3">
                              <div>
                                <div className="font-medium">Subtask #{child.id} · {categoryLabel(child.category)}</div>
                                <div className="text-sm text-muted-foreground">Preferred: {short(child.preferredAgent)}</div>
                              </div>
                              <StatusBadge status={child.status} />
                            </div>
                            <div className="mt-3 grid gap-1 text-sm text-muted-foreground">
                              <div>Assigned specialist: {short(child.assignedAgent)}</div>
                              <div>Reward: {prettyEth(child.rewardWei)}</div>
                              <div>Bond: {prettyEth(child.bondWeiRequired)}</div>
                              <div>Result URI: {child.resultURI || "Pending"}</div>
                            </div>
                          </div>
                        ))}
                      </CardContent>
                    </Card>
                  </>
                ) : (
                  <div className="text-sm text-muted-foreground">No parent job selected.</div>
                )}
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="agents" className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            {demoAgents.map((agent) => {
              const stats = agentStats[agent.address];
              const reputationScore = stats?.reputationScore ?? agent.reputation ?? 0;
              const bondedCompleted = stats?.bondedJobsCompleted ?? agent.bondedCompleted ?? 0;
              const bondBps = stats?.bondBps;
              const effectiveBondBps =
                reputationScore === 0 && (!bondBps || bondBps === 0) ? 3000 : bondBps;

              return (
                <Card key={agent.address} className="rounded-2xl shadow-sm">
                  <CardHeader>
                    <div className="flex items-center justify-between gap-3">
                      <CardTitle className="text-lg">{agent.name}</CardTitle>
                      <Badge variant="secondary">{agent.role}</Badge>
                    </div>
                  </CardHeader>

                  <CardContent className="grid gap-3 text-sm">
                    <div className="flex items-center gap-2 text-muted-foreground">
                      <Wallet className="h-4 w-4" />
                      {short(agent.address)}
                    </div>

                    <Separator />

                    <div>Reputation: <span className="font-medium">{reputationScore}</span></div>
                    <div>Bonded completed: <span className="font-medium">{bondedCompleted}</span></div>
                    <div>Bond tier: <span className="font-medium">{getBondTierLabel(effectiveBondBps, reputationScore)}</span></div>
                    <div>
                      Bond requirement:{" "}
                      <span className="font-medium">
                        {effectiveBondBps === undefined ? "Unknown" : `${effectiveBondBps} bps`}
                      </span>
                    </div>



                    <div className="flex flex-wrap gap-2 pt-2">
                      {agent.role !== "main" && (
                        <Badge variant="outline">Bonded Specialist</Badge>
                      )}

                      {agent.role === "main" && (
                        <Badge variant="outline">Human-Gated Settlement</Badge>
                      )}

                      <Badge variant="outline">{getReputationTier(reputationScore)}</Badge>

                      {bondBps > 0 && bondBps <= 1000 && (
                        <Badge variant="outline">Low Bond Requirement</Badge>
                      )}

                      {bondedCompleted > 0 && (
                        <Badge variant="outline">Proven Onchain</Badge>
                      )}
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </TabsContent>

          <TabsContent value="receipts" className="grid gap-4 lg:grid-cols-[0.8fr_1.2fr]">
            <Card className="rounded-2xl shadow-sm">
              <CardHeader>
                <CardTitle className="text-lg">Receipt Summary</CardTitle>
              </CardHeader>
              <CardContent className="grid gap-3 text-sm">
                <div className="rounded-2xl border p-4">
                  <div className="font-medium">Escrow behavior</div>
                  <div className="mt-2 text-muted-foreground">Specialists posted bonds, submitted results, and were paid only after the main agent marked the subtasks complete.</div>
                </div>
                <div className="rounded-2xl border p-4">
                  <div className="font-medium">Human-controlled final settlement</div>
                  <div className="mt-2 text-muted-foreground">The parent job remains under human control until approval. This is the key trust guarantee in the system.</div>
                </div>
              </CardContent>
            </Card>

            <Card className="rounded-2xl shadow-sm">
              <CardHeader>
                <CardTitle className="text-lg">Transaction / Result Panel</CardTitle>
              </CardHeader>
              <CardContent>
                <ScrollArea className="h-[420px] pr-4">
                  <div className="grid gap-4">
                    {[selectedParent, ...selectedChildren].filter(Boolean).map((job) => (
                      <div key={job.id} className="rounded-2xl border p-4">
                        <div className="flex items-center justify-between gap-3">
                          <div className="font-medium">{job.isSubtask ? `Subtask #${job.id}` : `Parent Job #${job.id}`}</div>
                          <StatusBadge status={job.status} />
                        </div>
                        <div className="mt-3 grid gap-2">
                          <TxRow label="Created" hash={job.txHashes?.created} />
                          <TxRow label="Accepted" hash={job.txHashes?.accepted} />
                          <TxRow label="Submitted" hash={job.txHashes?.submitted} />
                          <TxRow label="Completed" hash={job.txHashes?.completed} />
                        </div>
                        <div className="mt-3 rounded-xl bg-muted p-3 text-sm">
                          <div className="flex items-center gap-2"><FileText className="h-4 w-4" /> Result URI</div>
                          <div className="mt-2 break-all text-muted-foreground">{job.resultURI || "Pending"}</div>
                        </div>
                      </div>
                    ))}
                  </div>
                </ScrollArea>
              </CardContent>
            </Card>
          </TabsContent>

          
          <TabsContent value="logs" className="grid gap-4">
            <Card className="rounded-2xl shadow-sm">
              <CardHeader>
                <div className="flex items-center justify-between gap-3">
                  <CardTitle className="text-lg">Agent Log Panel</CardTitle>
                  <Button variant="outline" size="sm" onClick={refreshAgentLogs} className="gap-2">
                    <RefreshCcw className={`h-4 w-4 ${logsLoading ? "animate-spin" : ""}`} />
                    Refresh Logs
                  </Button>
                </div>
              </CardHeader>

              <CardContent className="grid gap-4 md:grid-cols-2">
                {agentLogs.map((agent) => {
                  const steps = agent.data?.steps || [];
                  const latestSteps = [...steps].slice(-8).reverse();

                  return (
                    <Card key={agent.key} className="rounded-2xl">
                      <CardHeader>
                        <CardTitle className="text-base">{agent.label}</CardTitle>
                      </CardHeader>

                      <CardContent className="grid gap-3">
                        <div className="text-xs text-muted-foreground">
                          Status: {agent.data?.status || "unknown"}
                        </div>

                        {latestSteps.length === 0 ? (
                          <div className="text-sm text-muted-foreground">
                            No log entries yet.
                          </div>
                        ) : (
                          <div className="grid gap-2">
                            {latestSteps.map((step: any, idx: number) => (
                              <div key={`${agent.key}-${idx}`} className="rounded-xl border p-3 text-sm">
                                <div className="flex items-center justify-between gap-3">
                                  <div className="font-medium">{step.action || "unknown_action"}</div>
                                  <Badge variant="secondary">Step {step.step ?? "?"}</Badge>
                                </div>

                                <div className="mt-2 text-xs text-muted-foreground break-all">
                                  {step.details ? JSON.stringify(step.details) : "No details"}
                                </div>

                                {step.tx_hash && (
                                  <div className="mt-2">
                                    <code className="rounded bg-muted px-2 py-1 text-xs">
                                      {step.tx_hash}
                                    </code>
                                  </div>
                                )}
                              </div>
                            ))}
                          </div>
                        )}
                      </CardContent>
                    </Card>
                  );
                })}
              </CardContent>
            </Card>
          </TabsContent>


        </Tabs>
      </div>
    </div>
  );
}