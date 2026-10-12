# Reflection Brief — Harness Engineering Capstone

**Name:**
**Date:**

Replace each `→` with your answer. **Every answer cites at least one artifact from your own runs** — a run ID, file path, token count, claim outcome, or test count. Uncited answers do not pass. 3–6 sentences each unless noted. Paste short artifact snippets where they help.

**Environment**

- Model(s):
- OS / Python:
- Approx. API spend:

---

## Part 1 — Per-system

### System 1 — Agentic loop

1. **Loop control.** Quote the `stop_reason` sequence from one trace. Name the file and function that decides continue-vs-stop, and how.
   → The sequence is multiple tool use and then end_turn.  The decison is made in claims_intake/loop.y.  It continue if stop reason is "tool_use".  It end when it is "end_turn" or "UnexpectedStopReason".

2. **Anti-pattern.** Name one anti-pattern `test_antipatterns.py` checks for. What would break in your run if the loop used it?
   → First it check if "done" in the text.  Second it check integer cap.  Then it check whether stop_reaons in the control loop.  Then check branching on claim type in the code.

3. **Tool design.** Pick two tools with overlapping inputs. How do the descriptions prevent misrouting? What did a structured tool error let the agent do that a generic string would not?
   → The route_to_adjuster and escalte_to_human may overlap.  Confience >= 0.6 and servrity assessed will route to adjuster.  Low confidence, contradictory facts, and unknow type would esclate to human.

4. **Your numbers.** Quote the turn count and cost for one claim. How does it differ from the README sample, and why?
   → My cost is $0.1474, but README says $0.05.  I got 5 route, 3 incompleted, and 0 escalated.  README expects 7 routed and 1 escalted.

### System 2 — Context strategy

5. **The reduction.** From `budget.json`: baseline tokens, assembled tokens, reduction %. Which section dominates the assembled context, and why keep it verbatim?
   → There was 56.41% reduction, from 38708 to 16874.  Active made up the main portion because the LLM require word for word for analysis.

6. **Summarize vs preserve.** State the rule for what gets summarized vs kept byte-exact, citing your per-section token numbers.
   → Live facts and active need byte-exact, while others could be summarized.  We need to keep exact for anything that is still in progress including ID, amount and status value.

7. **Facts block.** Compare `eval.jsonl` to `eval_control.jsonl`. Which question regressed, and what does that prove?
   → The exact status value for in_progress disapper and live only in conversation.  

### System 3 — Claude Code config

8. **Path-scoped rules.** Quote the glob frontmatter from one rule file. Why is it better than a directory-level CLAUDE.md for cross-cutting conventions?
   → The glob formatter match the file by patten whenever it qualify, while the directory path pattern only trigger when the file is containted in the folder.

9. **Forked skill.** Quote the `context: fork` and `allowed-tools` lines. What does running forked + read-only buy you? What breaks without it?
   → The "context: fork" would ensure the subagent run separately from main agent and would not dillute the information on the main context.  "Allowed-tool" with "Read-only" ensure the subagent won't alter the repository.

10. **Scope.** From the validator output: project-level vs user-level scope. Give one example of each from this config.
    → project level: .claude/commands/review.md.  user level is something that won't be shared with team.

### System 4 — Orchestration

11. **Push work down.** Defects the SQL query returned vs warm-tier total. Name the indexed query. Why does the model never see the full history?
    → the query is "Defect_Since" in warm.py, and it is backed by idx_defects_ts.  I need to put in number of row to be returned and warm-tier total count.  The limit on the query help ensure the size of data return won't grow overtime, so it won't query the whole history.

12. **Crash recovery.** The resume-vs-fresh decision and its staleness threshold (`recovery.py`). Why is a fresh start with an injected summary sometimes more reliable than resuming?
    → The crash vs recovery depend on the last run time vs now.  Sometimes it is better just to force fresh start to ensure the run is up-to-date.

13. **Small state.** Byte size of your `hot_state.json`. Why does the budget matter for a system run once per shift, indefinitely?
    → This ensure the size won't grow overtime unexpectedly, that would cost more when calling the claude api.

---

## Part 2 — Synthesis

*Graded on connecting two or more systems. Cite a named file/artifact from each.*

14. **Three layers.** Point to a file/artifact for each layer and justify.
    → Model: claims_intake/system_prompt.py - this is where the prompt is placed
    → Harness: claims_intake/loop.py and claims_intake/tools.py - the loop is driven by stop_reason returned.  It may resume after calling tool or end the call.
    → Orchestration: shift_monitor/pipeline.py, recovery.py and state.py - These determine if the call is still in progress, crash, or need to run fresh start.

15. **Deterministic vs prompt.** Cite one behavior guaranteed in code (terminal tool, read-only allowlist, atomic write, byte budget) and one guided by prompt. When is each right?
    →  Deterministic means same outcome every times it run, but prompt means the outcome would be different based on the context and the data.  Sometimes, the same data feed into the prompt multiple times would return different result.  If the assignment must has the same outcome, then deterministic coding would be idea; otherwise, if the assignment require thinking and outcome could be varied, then prompt would be preferred.

16. **Context, two faces.** Compare context management in System 2 (intra-session) and System 4 (cross-session) with cited numbers from both. Same principle, different mechanism — how?
    → Both give the models only what is needed to be run.  System 2 summarize the result, but system 4 filter the history and only provide recent events.

17. **Reliability you can't see in one run.** Name one behavior a test guarantees that a single successful run would not reveal. Why does it matter before shipping?
    → test_recovery_decide_truth_table - it test whether the run has finished and not exceed 30 min.  It matter because failure could happen unexpectedly we want the system could recover after system failure and not missing data.

18. **Blast radius.** Pick one system. What's the blast radius if it misbehaves, and what's the kill switch? Ground it in that system's tools, enforcement points, and state.
    → bad routing decision could cause the legitmate call to be route to wrong path and causing infinite loopo.  For example in the test_claim, we want to ensure the route is apporpriate.  There is a kill-switch of the max-token to ensure the call won't go infinite.

---

## Part 3 — Honest assessment

19. **What broke.** One thing that failed first try in your environment, and how you fixed it. (If nothing, what you checked to be sure.)
    → Some test failed, and I did use Claude code to help me fix it.

20. **What you'd change.** One architectural decision you'd make differently, grounded in what you observed.
    → For the forked execution one where we have 3 different subagent to analysis the outcome based on three different context, I would tweak it so it would search the internal documents like building a RAG system.
