# L5 — AI Agent Layer: Implementation with Claude Managed Agents

*BeTrueCore Modular System — Web3-ISM v1.2*
*ORCID: 0009-0004-4841-594X*
*Timestamped via OpenTimestamps (SHA-256)*

---

## Overview

This document specifies how BeTrueCore's L5 AI Agent layer is implemented
using [Claude Managed Agents](https://platform.claude.com/docs/en/managed-agents/overview)
(Anthropic). Managed Agents is in beta: every endpoint requires the
`managed-agents-2026-04-01` beta header, which the SDK sets automatically. The
published documentation states no release date, and none is claimed here. The
dates, status and identifiers in this document were checked against
platform.claude.com on 25 October 2026.

L5 is the observation layer of the BeTrueCore protocol.
It does not make decisions. It does not write to any data structure.
It witnesses and records — and reports back in a structured format. What it
reports is testimony, not measurement: the measuring is done by the map and by
the chain that recomputes against it.

What the report then does is part of the specification. The report is an input.
One agent of the nine — the Harmony Agent — draws the ethical signal and the
risk signal together and submits a verdict proposal on the outcome of a
dilemma: the cells of the 736-point map it found touched, their weights, the
counts of the result, and its own conclusion. `HarmonyAgent.sol` recomputes that
verdict from the submitted cells by the map's own rule and stores both — the
agent's conclusion and its own recomputation — so that any divergence stays
visible. That recomputation is not on the path a session takes today: no
contract calls it, and `finalizeSession` in `BeTrueCoreCore.sol` stores the
verdicts arriving in the submitted result without comparing them with anything.
The verdict a session carries is therefore the agent's conclusion, and the
recomputation is a record beside it rather than a check upon it. It is carried
as `not established on the finalization path` in `docs/AUTHORITY_CHAIN.md`,
§14, and closing it is a revision of the finalization path.
A verdict is issued for each side of a dilemma separately, and silence receives
none. An agent cannot alter a record, a verdict or a participant's weight, and
it can still be wrong about what it reports. Read-only closes the write path.
It does not close the content of the report, and nothing in this document
should be read as claiming otherwise.

This document answers the question: **how, exactly?**

---

## The Constitutional Constraint

Before any technical detail, the principle:

> *"The notary cannot be compelled to commit forgery — it has no technical mechanism."*

This holds for the register. A notary who cannot reach the book cannot alter
what is written in it, and that is what the two layers below enforce. It does
not hold for the testimony: what the agent says in its report is produced by a
language model reading text, and no layer below constrains it. The two are kept
apart throughout this document.

L5 read-only is not a policy. It is an architectural property enforced at two
independent layers simultaneously:

1. **Smart contract level:** `HarmonyAgent.sol` — the orchestrator contract that
   coordinates L5 agents holds no write permissions to any L0–L4 data structure.
   A compromised agent gains no action rights. What it gains is the content of
   its own report, which the contract aggregates and the community reads.

2. **API level:** the agent's `tools` configuration. The pre-built
   `agent_toolset_20260401` — `bash`, `read`, `write`, `edit`, `glob`, `grep`,
   `web_fetch` and `web_search` — is not declared on the agent at all, so none
   of those tools exist in the session. Only read-only MCP toolsets are
   declared, each with an explicit `permission_policy`: an MCP toolset left
   unconfigured defaults to `always_ask`, not to a denial, so the policy is
   stated rather than inherited. When the agent names a tool that is not
   enabled, the server denies the call without evaluating any policy: the
   `agent.tool_use` event carries `evaluated_permission: "deny"` and the agent
   receives an error result. A server denial cannot be overridden by the client.

Both layers must be compromised simultaneously for write access to occur.
This is the register half of the "notary cannot forge" guarantee in production,
and it is the half that permissions and contracts can carry. The testimony half
is addressed in the next section, which names the input surface the agents read
and states what is and is not closed there.

---

## The Input Surface — Participant-Authored Text

The agents read text that participants wrote. Prompts proposed by participants,
the three the community selects as the session agenda, and the session records
that carry them reach the model through `read_session_data` as part of the
observation task. This is the input surface, and it is the one surface of L5 an
outsider can write to by taking part.

A language model draws no architectural line between an instruction and a datum.
Text placed in a participant prompt can therefore be read by the agent as a
direction rather than as material, and no current technique prevents this. What
the architecture closes is action: an injected agent still has no write path to
L0–L4 and no tool beyond the read-only MCP toolsets, so it can alter no record,
no verdict, and no participant's weight. What the architecture does not close is
the content of the report — and that report is an input to the traffic light and
to the community reading the Panorama.

The full position — what is proven, what is assumed, and what is left outside
the guarantee — is in docs/AUTHORITY_CHAIN.md, §13. This specification does not
restate it and does not narrow it.

---

## The Nine-Agent Grid → Managed Agent Instances

L5 deploys nine agents of three types, each type operating as a distributed triad:

```
Analyst    × 3  — Vectorization, Filtration, and the Indicator agent, which
                  checks conformance to international ethical standards
Strategist × 3  — Ethical signal, risk signal, and the Harmony Agent's
                  verdict proposal
Sentinel   × 3  — Security, Coherence, and a third function this
                  specification does not yet name
```

In Claude Managed Agents, each of the nine agents is a **persistent agent
definition** created via `POST /v1/agents`. Each definition contains:

- A type-specific **system prompt** encoding that agent's canonical TDSH
  intersections from the 736-point ethical priority map (23 Asilomar × 32 TDSH)
- A **`tools` configuration** that declares no pre-built agent tools and only
  read-only MCP toolsets connecting to L4 (Celestia DA) through an MCP tunnel
- The **model assignment** (see Cost Model below)
- **No credentials** for any write-capable service

```python
# Example: one Analyst agent definition (simplified)
agent = client.beta.agents.create(
    name="btc-analyst-1",
    model="claude-sonnet-5-5",
    system=ANALYST_SYSTEM_PROMPT,   # encodes A06×T02, A12×T04, A10×T08
    mcp_servers=[
        {"type": "url", "name": "celestia-read", "url": CELESTIA_READ_MCP_URL},
        {"type": "url", "name": "vwu-snapshot", "url": VWU_SNAPSHOT_MCP_URL},
    ],
    tools=[
        # agent_toolset_20260401 is deliberately absent: no bash, no file
        # operations, no web search or fetch exist in the session.
        {"type": "mcp_toolset", "mcp_server_name": "celestia-read",
         "default_config": {"permission_policy": {"type": "always_allow"}}},
        {"type": "mcp_toolset", "mcp_server_name": "vwu-snapshot",
         "default_config": {"permission_policy": {"type": "always_allow"}}},
    ],
    # The SDK sends the managed-agents-2026-04-01 beta header itself.
)
```

The same pattern repeats for Strategist (canonical intersections: A17×T16,
A16×T14, A14×T09) and Sentinel (A18×T29, A19×T26, A11×T30).

A canonical intersection of an agent is a cell the map assigns to that agent.
The map assigns every TDSH parameter to exactly one of the three: T01–T08 to
the Analyst, T09–T16 to the Strategist, T17–T32 to the Sentinel. All nine cells
above are CRITICAL in the map, and all nine agree with `_populateTestMatrix`
in `test/BeTrueCore.t.sol`, which populates the same nine.

Harmony computation is the work of one agent, not of a triad. Of the three
Strategists, one reads ethical signal, one reads risk, and the third — the
Harmony Agent — draws those two together and proposes the verdict on the
outcome of a dilemma (see HarmonyAgent Orchestration Model below).
Conformance to international ethical standards is checked by the Indicator
agent of the Analyst triad. How material is divided between those two agents is
an open point of this specification, and it is marked as open here rather than
settled in passing.

The nine sessions are isolated from one another, and that isolation bounds a
fault in any one session. It does not bound an injection, because all nine read
the same session data: text that steers one agent reaches the other eight in the
same form. The triad structure gives redundancy against a session failing or
drifting. It gives none against a payload in the shared input, and this document
does not present it as a defence against one.

---

## TDSH Matrix as Outcomes Rubric

Claude Managed Agents lets a session be given an outcome, under the same
`managed-agents-2026-04-01` beta: you send a `user.define_outcome` event
carrying a description and a rubric, and the harness provisions a separate
grader that scores the artifact against that rubric in its own context window,
so the agent's implementation choices cannot influence the verdict. The rubric
is required, not optional, and is a markdown document of per-criterion scoring.
The grader returns which criteria passed or failed, the agent revises, and the
cycle repeats up to `max_iterations` (default 3, maximum 20). The published
documentation states no release date for the feature.

For BeTrueCore L5, the relevant subset of the TDSH 736-point matrix serves
directly as this rubric. Each agent type receives its three canonical
intersections as an Outcomes definition:

```python
# Analyst Outcomes rubric (sent as user event at session start).
# Cell names below are the map's own; they are not paraphrased.
ANALYST_RUBRIC = """
Evaluate your observation report against these criteria:
1. A06×T02 (Safety × Factual Purity):
   All inputs are cryptographically verified ZK-SNARK outputs.
   No backend assertions. No unverifiable data sources.
   Nothing enters the report that an L4 record cannot account for.
2. A12×T04 (Personal Privacy × Critical Distance):
   The report names no participant and carries no quantity from which one
   could be singled out. Every observation is attributable to a specific L4
   record and to no person. What was observed and what is concluded from it
   are stated separately, never merged into one claim.
3. A10×T08 (Value Alignment × Reflexive Monitoring):
   No VWU assignment occurs. Agent reports patterns only.
   Final signal weight is determined by participant action, not agent assessment.
   The report states what could not be observed alongside what was.

If any criterion is unmet, revise and recheck. Output: JSON signal only, one of
green, yellow, red or undetermined. Report undetermined when no measurement was
made; never report green in its place.
"""
```

This is not prompt-engineering — it is the 736-point ethical matrix
operationalised as a machine-executable rubric, scored by a grader separate from
the agent it grades. The separation is of context, not of trust: the grader is
itself a model, and it reads the report the agent produced. Where that report
carries text copied from a participant prompt, the grader reads that text too.
A grader catches an agent that drifted from the rubric. It is not a control
against an input that steered both.

The control that does not depend on a model is structural: the signal returned
to the contract is validated against a fixed JSON schema in ordinary code before
it is submitted on-chain — the five fields given below, `signal` restricted to
`green`, `yellow`, `red` or `undetermined`, `metric` to a number, and free text
accepted in no field. `undetermined` is a value in its own right and not an
error state: it says that no measurement was made, and nothing stands in for it.
Green is a finding, never a default, and the schema admits no signal that lets
an absent measurement read as a green one. A schema-valid signal can still be a
wrong signal. What the check guarantees is that nothing but a signal crosses the
boundary into L4.

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

Two names have to be kept apart here. `HarmonyAgent.sol` is the orchestrating
contract. The Harmony Agent is one of the nine L5 agents, the third Strategist.
They are not the same thing, and the contract is not a machine copy of the
agent: the agent proposes, the contract recomputes. Where this document says
"the contract", the orchestrator is meant; where it says "the Harmony Agent",
the L5 agent is meant.

This matters for the authority chain. The orchestration logic is on-chain,
verifiable, and cannot be modified by any agent. The nine Managed Agent
sessions receive task parameters from the contract and return structured JSON
signals. The Harmony Agent returns more than a signal: for the outcome of each
dilemma it submits the cells of the 736-point map it found touched, their
weights, the counts of the result, and its own conclusion — one conclusion per
side of the dilemma, and none for silence. `HarmonyAgent.sol` does not enter
that conclusion as the verdict. It recomputes the verdict itself from the
submitted cells, by the map's own rule, and writes both to L4 side by side: the
agent's conclusion and the chain's recomputation. A divergence between the two
is left visible to a reader instead of being resolved silently in favour of
either. No agent controls the flow — the flow is mathematics.

**What the flow does not yet include.** `computeFinalVerdict` is called by no
contract of the package. `BeTrueCoreCore` holds a pointer to the orchestrating
contract and never uses it: `finalizeSession` takes the two verdicts out of the
submitted result and compares them with nothing. The recomputation therefore
runs beside the session rather than inside it, and a coordinator may recompute
one verdict and finalize another with no check noticing. Until finalization
draws its verdicts from that computation, or refuses a result that disagrees
with it, this section describes a function that is available, not a guarantee
that is enforced. Recorded as `not established on the finalization path` in the
requirements table of `docs/AUTHORITY_CHAIN.md`, §14.

The rule and the evidence have to be told apart here. The rule is fixed: the
aggregation the contract performs is the same whatever the nine signals say, and
no agent can change it. The evidence is not fixed: the signals are what the
agents report, and an agent steered by its input reports a different signal.
Fixed arithmetic over altered evidence gives an altered result, and calling the
flow mathematics does not make its inputs true.

This is "AI as notary, not judge" in its precise technical form: the agent never
rules on the matter, and the weight its testimony carries is set by the contract
and not by the agent. A notary's signature attests that the witness spoke, not
that the witness was right. Across the three MVP pilot trials the orchestrator stays the same contract; only the holder
of the coordinating role changes: the human operator with mathematical support,
then mathematics as the operator, then the community through the protocol itself.

---

## Event Taxonomy Relevant to BeTrueCore

Claude Managed Agents groups events into five persisted categories — user,
agent, session, span and system — plus stream-only event deltas. The types this
specification relies on:

| Event type | BeTrueCore use |
|---|---|
| `user.define_outcome` | TDSH matrix rubric sent at session start |
| `user.interrupt` | Halts the agent mid-execution. Constitutional principle: "Human is final judge." See the note below on who can send it. |
| `agent.mcp_tool_use` / `agent.mcp_tool_result` | Read-only calls to Celestia DA through the MCP tunnel |
| `agent.thread_context_compacted` | Context window management for long voting sessions |
| `session.status_running` / `session.status_idle` / `session.status_terminated` | Session lifecycle, mapped to the voting session lifecycle |
| `span.model_request_start` / `span.model_request_end` | Timing and token usage of each model call |
| `span.outcome_evaluation_start` / `span.outcome_evaluation_end` | Grader iterations over the TDSH rubric |

The `user.interrupt` event is where the constitutional principle meets an
external dependency. An interrupt is an API call against the session, not a
smart contract operation: a contract cannot send one, and whoever holds the API
credentials can. The halt is therefore an organisational guarantee, and this
document states it as one. What the contract does enforce runs the other way: an
agent, interrupted or not, has no write path to L0–L4 to begin with.

---

## Self-Hosted Sandboxes → Phase 3 Decentralisation

Claude Managed Agents supports **self-hosted sandboxes**, under the same
`managed-agents-2026-04-01` beta: tool execution moves to infrastructure you
control while Anthropic keeps running the model. A `self_hosted` environment
acts as a work queue. An environment worker on your own host claims each session
from that queue, runs every tool call locally, and posts the result back.
Pre-built workers ship with the `ant` CLI and the Python, TypeScript and Go
SDKs, and Anthropic publishes platform guides for Cloudflare, Modal, Vercel,
Daytona, E2B and others. The published documentation states no release date.

This is the Phase 3 path for BeTrueCore:

| Phase | L5 Infrastructure | Operator Role |
|---|---|---|
| Phase 1 | Anthropic-managed sandboxes | Human operator coordinates |
| Phase 2 | Anthropic or self-hosted | Lit Protocol MPC assumes coordinator role |
| Phase 3 | Community-owned sandbox fleet | Contract-driven; the one human action left is `user.interrupt`, available to whoever holds the API credentials |

In Phase 3, the sandbox fleet is owned and operated by the BeTrueCore community,
and the nine agents execute their tool calls on community infrastructure. The
dependency is narrowed, not removed, and this document says so plainly: the model
itself still runs on Anthropic's side, and every tool input and output still
passes through Anthropic's control plane, because the model has to read each
result to decide what to do next. Self-hosting controls where the agent's code
executes, not who runs the agent.

Phase 1 accepts Anthropic as the infrastructure provider for
speed-to-production. Phase 3 keeps tool execution, session files and network
egress inside community infrastructure, while the model request remains
external. Removing that last dependency would mean observation by a model the
community itself runs, which is outside the scope of this specification.

One thing about the coordinating role is stated here and not softened. While an
address holds that role, that it belongs to the community cannot be proved. It
is disclosed, not proved: who holds the key is named publicly, and a reader is
relied upon to look. No statute closes this — a community has no legal
personality and needs none, and the statutes of the association that operates
the application are the association's, not the community's. The role becomes
proved by disappearing: by Phase 3 the community governs through the protocol
itself, and there is nothing left for anyone to hold. Every transfer of the role
runs in two steps — the holder nominates, the nominee accepts — and both steps
emit events, so a change of hands is visible rather than silent. The full
position is in docs/AUTHORITY_CHAIN.md, §14.

---

## MCP Tunnels → Private L5→L4 Channel

L4 (Celestia DA) stores the immutable public audit log of all voting sessions.
L5 agents need read access to this data. The data must not transit the public
internet unencrypted.

Claude Managed Agents **MCP tunnels** let a private MCP server inside your own
network be reached by managed agent sessions without being exposed on the
internet. MCP tunnels are a limited research preview: access must be requested,
and the tunnel management API carries its own beta, separate from the Managed
Agents one. Its exact header string is not given on the pages read, so none is
quoted here. Until access is granted this channel is planned rather than
available, and the preview is published without any uptime, support or
continuity commitment, on a third-party transport that carries none either. That
makes it an external dependency of L5 twice over, and it is named here as one.
The MCP server acts as a read-only gateway to Celestia DA:

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
bypassed the `tools` configuration would face a second read-only boundary at the
gateway. Neither boundary constrains what the agent writes in its report, since
the report is not a tool call.

---

## Agent Versioning → Auditable TDSH Governance

Claude Managed Agents versions every agent definition. A change to the system
prompt, the tools configuration or the model assignment creates a new version,
numbered from 1 upward, and the full history can be listed through the API.
A session references an agent; pinning a session to an earlier version is not
documented, so this specification does not rely on it.

For BeTrueCore, this provides:

**TDSH parameter governance:** Any change to the 736-point matrix — adding a
rule, adjusting a threshold, updating a canonical intersection — results in a
new agent version with a timestamped record of what changed and when. The TDSH
matrix is not just a document; it is a versioned artifact whose change history
is auditable.

**Rollback capability:** if a new matrix version produces anomalous agent
behaviour in testing, the previous configuration is restored by updating the
agent back to it, which is recorded as a further version. Sessions already
running keep the configuration they started with; sessions created afterwards
get the restored one. Nothing is lost, because every earlier version stays in
the history.

**Upgrade governance (Phase 3):** agent version upgrades are approved through a
BeTrueCore session, so the upgrade path is governed by the same protocol that
governs collective decisions — recursive constitutional coherence. The key that
applies an approved upgrade is held by an address, and that this address answers
to the community is disclosed rather than proved, on the same terms as the
coordinating role above (docs/AUTHORITY_CHAIN.md, §14). Sessions do not continue
one another: an upgrade approved in one session is approved by that session, and
the next day's agenda may be formed around something else entirely.

---

## Implementation Sketch

Minimal production-ready L5 session for one Analyst agent:

```python
import os
from anthropic import Anthropic

client = Anthropic()

ANALYST_SYSTEM = """
You are BeTrueCore Analyst Agent — a read-only observer of collective decision
sessions. You witness and record. What you report is testimony, not
measurement. You never write, modify, or influence any data structure.

Constitutional constraint: A01 (Research Goal) is not a variable you can access
or influence. Your role is observation only.

Canonical intersections: A06×T02, A12×T04, A10×T08.
Output format: JSON signal only.
Structure: {"signal": "green|yellow|red|undetermined", "metric": <number>,
            "layer": "L5-Analyst", "agent_id": "<id>", "session_ref": "<ref>"}
Report "undetermined" when no measurement was made. Never report green in its
place: green is a finding, not a default.
"""

# STRATEGIST_SYSTEM and SENTINEL_SYSTEM follow the same shape, each naming its
# own canonical intersections — A17×T16, A16×T14, A14×T09 for the Strategist,
# A18×T29, A19×T26, A11×T30 for the Sentinel — and each with its own rubric.

# One-time setup. Each of the three types is its own persistent agent
# definition, referenced by ID. None of them carries pre-built tools:
# agent_toolset_20260401 is not declared, so bash, file writes and the web
# tools do not exist in any session of these agents. The environment is created
# once (Console or API) and referenced by ID; see the environments guide.
AGENT_IDS = {
    "analyst":    os.environ["BTC_ANALYST_AGENT_ID"],
    "strategist": os.environ["BTC_STRATEGIST_AGENT_ID"],
    "sentinel":   os.environ["BTC_SENTINEL_AGENT_ID"],
}
RUBRICS = {
    "analyst":    ANALYST_RUBRIC,
    "strategist": STRATEGIST_RUBRIC,
    "sentinel":   SENTINEL_RUBRIC,
}
L5_ENVIRONMENT_ID = os.environ["BTC_L5_ENVIRONMENT_ID"]

def start_agent_session(
    agent_type: str, voting_session_id: str, agent_label: str
) -> str:
    """Start one read-only observation session and return its session ID."""
    session = client.beta.sessions.create(
        agent=AGENT_IDS[agent_type],
        environment_id=L5_ENVIRONMENT_ID,
        title=f"L5 {agent_label} · voting session {voting_session_id}",
        initial_events=[
            {
                "type": "user.define_outcome",
                "description": (
                    f"Observe voting session {voting_session_id} and report "
                    "participation pattern anomalies as traffic-light JSON. "
                    "No prose."
                ),
                "rubric": {"type": "text", "content": RUBRICS[agent_type]},
                "max_iterations": 3,
            }
        ],
    )
    return session.id

def start_observation_round(voting_session_id: str) -> list[str]:
    """
    Nine sessions per voting round — each isolated, each read-only, three per
    type. The type decides the agent definition and the rubric, not the label:
    a session started under the Analyst definition is an Analyst session
    whatever it is called.
    HarmonyAgent.sol cannot call the API itself: a contract makes no outbound
    requests. A relay watches the contract's events, holds the API credentials,
    starts these sessions, and submits the aggregated signals back on-chain.
    That relay is an external dependency of L5, not a protocol guarantee.
    """
    return [
        start_agent_session(agent_type, voting_session_id, f"{agent_type}-{i}")
        for agent_type in ("analyst", "strategist", "sentinel")
        for i in range(1, 4)
    ]

def collect_signals(session_ids: list[str]) -> list[dict]:
    """
    Read each session's outcome once its grader has finished. Progress also
    arrives live on the event stream as span.outcome_evaluation_* events.
    """
    signals = []
    for session_id in session_ids:
        session = client.beta.sessions.retrieve(session_id)
        for outcome in session.outcome_evaluations:
            signals.append({"session_id": session_id, "result": outcome.result})
    return signals
```

---

## Cost Model

For reference during Phase 1 budgeting. A round here is one voting session of
the protocol — one dilemma, from `openSession` to `finalizeSession` — with the
nine agent sessions above running inside it, one per agent. The code calls the
same thing `voting_session_id`.

| Item | Cost |
|---|---|
| Session runtime | $0.08 per session-hour, assumed; see the note below |
| Idle, rescheduling, terminated | $0.00 — none of it counts toward runtime |
| claude-sonnet-5-5 tokens | $2 / $10 per MTok, checked 25 October 2026 |
| 9 sessions × 30 min, assumed | ~$0.36 runtime (4.5 session-hours × $0.08) |
| Token cost per round, estimated | ~$0.10–0.20 |
| **Total per round, estimated** | **~$0.50–0.60** |

**What these figures assume.** The session-hour rate is the weakest line in the
table and is marked as such: Anthropic's published Managed Agents documentation
carries no pricing page, and the rate above was not found there on
25 October 2026. Every runtime figure below it inherits that status. The token
rate is different in kind — $2 / $10 per MTok for `claude-sonnet-5-5` is
published and was checked on the same date. Thirty minutes per agent session is
a budgeting assumption, not a property of the design: the protocol fixes no such
length.
The voting session runs for `duration_seconds`, set by the coordinator when it
opens, and an agent session is a different thing again — started by the relay,
ended when its grader finishes. The token figure rests on no stated volume and
is an order of magnitude, not a price. Both lines are to be replaced by
measurements from the first pilot, and until then they are presented as what
they are: tens of cents per round, under assumptions written down here so that
a reader can check them rather than infer them.

**How cost scales.** Runtime is linear in the number of agent sessions — nine —
and not in the number of participants: nine sessions are nine sessions whether
a hundred people took part or ten thousand. Tokens are not. The agents read what
participants wrote, so the text they read grows with the community, and the
token line above grows with it. The claim that a session of ten thousand costs
the same as a session of a hundred held only for runtime and was stated too
widely; what holds is that the *number of sessions* does not grow with the
community.

---

## Why This Is Not Claude Projects

A common question: why not just use Claude Projects with custom instructions?

| Dimension | Claude Projects | BeTrueCore L5 (Managed Agents) |
|---|---|---|
| Read-only enforcement | Prompt-level (policy) | API-level (`tools` configuration + `permission_policy`) + smart contract |
| Agent persistence | Session-local | Cross-session persistent agent definitions |
| Multi-agent coordination | No | Nine parallel isolated sessions per voting round |
| Versioning | None | Full version history, auditable |
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
- [The DNA of Ethical AI Agents — Zenodo preprint](https://doi.org/10.5281/zenodo.20771227)
- [The Notary Under Attack — Zenodo preprint](https://doi.org/10.5281/zenodo.21111544)
- [TDSH Four Principles — Zenodo preprint](https://doi.org/10.5281/zenodo.21466246)
- [Claude Managed Agents — Official Documentation](https://platform.claude.com/docs/en/managed-agents/overview)
- [HarmonyAgent.sol](../src/HarmonyAgent.sol)
- [EthicalMatrix.sol](../src/EthicalMatrix.sol)

---

*BeTrueCore Modular System — Web3 Intuitive Symmetry Methodology (Web3-ISM) v1.2*
*Repository: [github.com/Dede-Qorqud/BeTrueCore](https://github.com/Dede-Qorqud/BeTrueCore)*
*Timestamped via OpenTimestamps (SHA-256)*