# L5 — AI Agent Layer: Implementation with Claude Managed Agents

*BeTrueCore Modular System — Web3-ISM v1.2*
*ORCID: 0009-0004-4841-594X*
*Timestamped via OpenTimestamps (SHA-256)*

---

## Overview

This document specifies how BeTrueCore's L5 AI Agent layer is implemented
using [Claude Managed Agents](https://platform.claude.com/docs/en/managed-agents/overview)
(Anthropic, public beta since April 8, 2026).

L5 is the observation and measurement layer of the BeTrueCore protocol.
It does not make decisions. It does not write to any data structure.
It witnesses, records, and measures — and reports back in a structured format.

This document answers the question: **how, exactly?**

---

## The Constitutional Constraint

Before any technical detail, the principle:

> *"The notary cannot be compelled to commit forgery — it has no technical mechanism."*

L5 read-only is not a policy. It is an architectural property enforced at two
independent layers simultaneously:

1. **Smart contract level:** `HarmonyAgent.sol` — the orchestrator contract that
   coordinates L5 agents holds no write permissions to any L0–L4 data structure.
   A compromised agent gains observation rights, not action rights.

2. **API level:** Claude Managed Agents `allowed_tools` parameter — an explicit
   whitelist of tools the agent may call. No write tool is ever included.
   If an agent attempts to call an unlisted tool, the call fails with a clean error.
   There is no override path.

Both layers must be compromised simultaneously for write access to occur.
This is the "notary cannot forge" guarantee in production.

---

## The Nine-Agent Grid → Managed Agent Instances

L5 deploys nine agents of three types, each type operating as a distributed triad:

```
Analyst   × 3  — Vectorization and Filtration (VWU 1–3)
Strategist × 3  — Harmony Computation (VWU 4–6)
Sentinel  × 3  — Security and Coherence (VWU 7–9)
```

In Claude Managed Agents, each of the nine agents is a **persistent agent
definition** created via `POST /v1/agents`. Each definition contains:

- A type-specific **system prompt** encoding that agent's canonical TDSH
  intersections from the 736-point ethical priority map (23 Asilomar × 32 TDSH)
- An **`allowed_tools` whitelist** containing only read-only custom tools
  connecting to L4 (Celestia DA) via MCP tunnel
- The **model assignment** (see Cost Model below)
- **No credentials** for any write-capable service

```python
# Example: one Analyst agent definition (simplified)
agent = client.beta.agents.create(
    name="btc-analyst-1",
    model="claude-sonnet-4-6",
    system=ANALYST_SYSTEM_PROMPT,   # encodes A06×T18, A12×T04, A08×T02
    tools=[
        {"type": "mcp", "server": "celestia-read-mcp"},  # read-only
        {"type": "mcp", "server": "vwu-snapshot-mcp"},   # read-only
    ],
    # No bash, no web search, no file write — nothing that touches state
    beta_header="managed-agents-2026-04-01",
)
```

The same pattern repeats for Strategist (canonical intersections: A17×T00,
A14×T28, A16×T06) and Sentinel (A18×T19, A19×T08, A11×T05).

---

## TDSH Matrix as Outcomes Rubric

Claude Managed Agents introduced the **Outcomes** feature: you pass the agent a
specification (a rubric), and the agent iterates against that rubric — checking
its own output — until the rubric is satisfied.

For BeTrueCore L5, the relevant subset of the TDSH 736-point matrix serves
directly as this rubric. Each agent type receives its three canonical
intersections as an Outcomes definition:

```python
# Analyst Outcomes rubric (sent as user event at session start)
ANALYST_RUBRIC = """
Evaluate your observation report against these criteria:
1. A06×T18 (Research Transparency × Data Accuracy):
   All inputs are cryptographically verified ZK-SNARK outputs.
   No backend assertions. No unverifiable data sources.
2. A12×T04 (AI Transparency × Transparency Index):
   Every observation is attributable to a specific L4 record.
   Audit trail is independently recomputable without BeTrueCore backend.
3. A08×T02 (Value Alignment × Meritocracy):
   No VWU assignment occurs. Agent reports patterns only.
   Final signal weight is determined by participant action, not agent assessment.

If any criterion is unmet, revise and recheck. Output: JSON traffic-light only.
"""
```

This is not prompt-engineering — it is the 736-point ethical matrix
operationalised as a machine-executable self-evaluation loop.

**Architectural constraint:** A01 (Research Goal) is a frozen constant of the
protocol. It is not passed to L5 agents at runtime and is not part of any
Outcomes rubric. The goal the system serves is not a variable the agents can
influence.

---

## HarmonyAgent Orchestration Model

A critical distinction from generic multi-agent patterns:

In Claude Managed Agents documentation, the typical orchestrator is an LLM agent
that reasons about subtask decomposition. In BeTrueCore, the orchestrator is
**`HarmonyAgent.sol`** — a smart contract.

```
HarmonyAgent.sol  (orchestrator — smart contract, NOT an LLM)
    │
    ├── Analyst-1 session    (Claude Managed Agent — read-only)
    ├── Analyst-2 session    (Claude Managed Agent — read-only)
    ├── Analyst-3 session    (Claude Managed Agent — read-only)
    ├── Strategist-1 session (Claude Managed Agent — read-only)
    ├── Strategist-2 session (Claude Managed Agent — read-only)
    ├── Strategist-3 session (Claude Managed Agent — read-only)
    ├── Sentinel-1 session   (Claude Managed Agent — read-only)
    ├── Sentinel-2 session   (Claude Managed Agent — read-only)
    └── Sentinel-3 session   (Claude Managed Agent — read-only)
```

This matters for the authority chain. The orchestration logic is on-chain,
verifiable, and cannot be modified by any agent. The nine Managed Agent sessions
receive task parameters from the contract and return structured JSON signals.
The contract aggregates signals. No agent controls the flow — the flow is
mathematics.

This is "AI as notary, not judge" in its precise technical form: in Phase 1,
the human operator coordinates through `HarmonyAgent.sol`; in Phase 3,
`HarmonyAgent.sol` coordinates autonomously with community-held keys.

---

## Event Taxonomy Relevant to BeTrueCore

Claude Managed Agents exposes four event types. Their mapping to BeTrueCore:

| Event Type | BeTrueCore Use |
|---|---|
| **User Events → Outcomes** | TDSH matrix rubric injected at session start |
| **User Events → Interrupts** | Human-in-the-loop: operator can halt agent if anomalous behaviour detected. Constitutional principle: "Human is final judge." |
| **Agent Events → Tool calls** | Read-only calls to Celestia DA via MCP tunnel |
| **Agent Events → Compaction** | Context window management for long voting sessions |
| **Session Events → Lifecycle** | idle → running → terminate mapped to voting session lifecycle |
| **Span Events** | Monitoring start/end of long observation passes (e.g., full session analysis) |

The **Interrupts** event type directly implements the constitutional principle.
Even in Phase 3, the operator retains a single emergency mechanism: the ability
to send an interrupt that halts agent processing. This mechanism exists at the
smart contract level, not at the AI level.

---

## Self-Hosted Sandboxes → Phase 3 Decentralisation

Claude Managed Agents supports **self-hosted sandboxes**: instead of running
agent sessions on Anthropic infrastructure, you connect your own containers
(Cloudflare Workers, Modal, Vercel, or a private fleet). Anthropic signals when
Claude needs a new sandbox — you provision and connect it.

This is the Phase 3 path for BeTrueCore:

| Phase | L5 Infrastructure | Operator Role |
|---|---|---|
| Phase 1 | Anthropic-managed sandboxes | Human operator coordinates |
| Phase 2 | Anthropic or self-hosted | Lit Protocol MPC assumes coordinator role |
| Phase 3 | Community-owned sandbox fleet | Smart contract only; no human in loop |

In Phase 3, the sandbox fleet is owned and operated by the BeTrueCore community.
The nine agents run on community infrastructure. Anthropic is no longer a runtime
dependency — only the model weights remain (fetched via API). The decentralisation
of the observation layer mirrors the decentralisation of the decision layer.

This closes the vendor dependency concern: the current architecture (Phase 1)
accepts Anthropic as infrastructure provider for speed-to-production. Phase 3
eliminates this dependency without changing the agent logic.

---

## MCP Tunnels → Private L5→L4 Channel

L4 (Celestia DA) stores the immutable public audit log of all voting sessions.
L5 agents need read access to this data. The data must not transit the public
internet unencrypted.

Claude Managed Agents **MCP tunnels** allow a private MCP server running inside
a VPC to be accessed by managed agent sessions without being exposed on the
internet. The MCP server acts as a read-only gateway to Celestia DA:

```
[L5 Agent session]
      │  (encrypted MCP tunnel)
      ▼
[celestia-read-mcp server]  ← private VPC
      │  (internal)
      ▼
[Celestia DA node]
```

The gateway enforces read-only at the application layer: it exposes only
`read_session_data`, `read_proof_record`, and `compute_vwu_snapshot` — no
write endpoints exist in the MCP server schema. A compromised agent that somehow
bypassed `allowed_tools` would face a second read-only boundary at the gateway.

---

## Agent Versioning → Auditable TDSH Governance

Claude Managed Agents versions every agent definition. A change to the system
prompt, the allowed tools list, or the model assignment creates a new version.
Previous versions are retained. Sessions can be pinned to a specific version.

For BeTrueCore, this provides:

**TDSH parameter governance:** Any change to the 736-point matrix — adding a
rule, adjusting a threshold, updating a canonical intersection — results in a
new agent version with a timestamped record of what changed and when. The TDSH
matrix is not just a document; it is a versioned artifact whose change history
is auditable.

**Rollback capability:** If a new matrix version produces anomalous agent
behaviour in testing, the previous version can be restored by pinning sessions
to the prior agent version. No irreversible changes.

**Upgrade governance (Phase 3):** Community-controlled key-holders approve
agent version upgrades via a BeTrueCore governance vote. The upgrade path itself
is governed by the same protocol that governs collective decisions — recursive
constitutional coherence.

---

## Implementation Sketch

Minimal production-ready L5 session for one Analyst agent:

```python
import anyio
from anthropic import Anthropic
from claude_agent_sdk import ClaudeSDKClient, ClaudeAgentOptions, tool

client = Anthropic()

# Read-only tools — no write surface
@tool(description="Read session signal from Celestia DA (read-only)")
def read_session_record(session_id: str, slot: int) -> dict:
    return celestia_mcp_client.read(session_id, slot)

@tool(description="Compute VWU distribution snapshot for session")
def compute_vwu_snapshot(session_id: str) -> dict:
    return vwu_calculator.snapshot(session_id)

ANALYST_SYSTEM = """
You are BeTrueCore Analyst Agent — a read-only observer of collective decision
sessions. You witness, record, and measure. You never write, modify, or influence
any data structure.

Constitutional constraint: A01 (Research Goal) is not a variable you can access
or influence. Your role is observation only.

Canonical intersections: A06×T18, A12×T04, A08×T02.
Output format: JSON traffic-light signal only.
Structure: {"signal": "green|yellow|red", "metric": "<value>",
            "layer": "L5-Analyst", "agent_id": "<id>", "session_ref": "<ref>"}
"""

async def run_analyst_session(voting_session_id: str, agent_id: str) -> dict:
    options = ClaudeAgentOptions(
        system_prompt=ANALYST_SYSTEM,
        allowed_tools=["read_session_record", "compute_vwu_snapshot"],
        # No bash, no web_search, no file_write — enforced at API level
        model="claude-sonnet-4-6",
        max_turns=5,  # Hard limit — agents do not reason indefinitely
    )
    async with ClaudeSDKClient(options=options) as agent:
        signal = await agent.query(
            f"Observe session {voting_session_id}. "
            "Report participation pattern anomalies. "
            "Return traffic-light JSON only. No prose."
        )
        return {"agent_id": agent_id, "signal": signal}

async def harmony_orchestrator(voting_session_id: str) -> list:
    """
    HarmonyAgent.sol calls this function via smart contract event.
    Nine parallel sessions — each isolated, each read-only.
    """
    tasks = [
        run_analyst_session(voting_session_id, f"analyst-{i}") 
        for i in range(1, 4)
    ]
    # Strategist × 3 and Sentinel × 3 added analogously
    results = await anyio.gather(*tasks)
    return aggregate_signals(results)
```

---

## Cost Model

For reference during Phase 1 budgeting:

| Item | Cost |
|---|---|
| Active runtime | $0.08 / agent-hour |
| Idle time (waiting for input) | $0.00 |
| claude-sonnet-4-6 tokens | Standard API pricing |
| 9 agents × 30-min session | ~$0.36 runtime |
| Token cost per session (est.) | ~$0.10–0.20 |
| **Total per voting session (est.)** | **~$0.50–0.60** |

Cost is linear with number of sessions, not with number of participants. A
session with 10,000 participants costs the same in L5 as a session with 100.

---

## Why This Is Not Claude Projects

A common question: why not just use Claude Projects with custom instructions?

| Dimension | Claude Projects | BeTrueCore L5 (Managed Agents) |
|---|---|---|
| Read-only enforcement | Prompt-level (policy) | API-level (`allowed_tools`) + smart contract |
| Agent persistence | Session-local | Cross-session persistent agent definitions |
| Multi-agent coordination | No | Nine parallel isolated sessions per voting round |
| Versioning | None | Full version history, pinnable, auditable |
| Self-hosting | No | Phase 3: community infrastructure |
| Orchestration | Human | `HarmonyAgent.sol` (smart contract) |
| TDSH matrix operationalisation | Prompt suggestion | Outcomes rubric with self-evaluation loop |
| Audit trail | None | Full event log per session in developer console |

Claude Projects is a chat interface. BeTrueCore L5 is an architectural layer
with verifiable constraints. The difference is not configuration — it is the
level at which the constraint is enforced and audited.

---

## References

- [BeTrueCore Architecture Foundation](./ARCHITECTURE_FOUNDATION.md)
- [The DNA of Ethical AI Agents — Zenodo preprint](https://doi.org/10.5281/zenodo.21111544)
- [TDSH Four Principles — Zenodo preprint](https://doi.org/10.5281/zenodo.21466246)
- [Claude Managed Agents — Official Documentation](https://platform.claude.com/docs/en/managed-agents/overview)
- [HarmonyAgent.sol](./contracts/HarmonyAgent.sol)
- [EthicalMatrix.sol](./contracts/EthicalMatrix.sol)

---

*BeTrueCore Modular System — Web3 Intuitive Symmetry Methodology (Web3-ISM) v1.2*
*Repository: [github.com/Dede-Qorqud/BeTrueCore](https://github.com/Dede-Qorqud/BeTrueCore)*
*Timestamped via OpenTimestamps (SHA-256)*
