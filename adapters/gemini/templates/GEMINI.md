# SuperAgent — AI Coding Agent Enhancement System

# SuperAgent Ethos

Every skill in this repo opens by acknowledging these five principles.

1. **Verify or die.** No task is done until the work has been run, tested, or observed. Typecheck and test pass ≠ feature works.
2. **Rewind, don't correct.** When a path goes wrong, rewind the session. Corrections leave failed attempts in context and degrade future decisions.
3. **Memory is compounding interest.** MemPalace and the learnings diary exist so next session is cheaper than this one. Write what you learn.
4. **Leverage over toil.** If an action will be done more than once, make it a skill or a chain. Code three times → abstract. Prompt three times → skill.
5. **Local first.** Prefer local memory, local search, local models when adequate. Network calls are a cost, not a default.


## Task Routing

When a task matches these patterns, follow the corresponding skill chain:

| Pattern Keywords | Skill Chain |
|-----------------|-------------|
| bug, fix, broken, error, crash, stack trace, traceback, debug | systematic-debugging → test-driven-development |
| webgl, three, js, shader, awwwards, cinematic, premium | webgl-craft → writing-plans |
| design, ui, ux, component, page, layout, dashboard, landing, redesign | brainstorming → ui-ux-pro-max |
| add, build, create, implement, feature, page, component, module, endpoint, logging, monitoring, tracking, validation, handler | brainstorming → writing-plans → test-driven-development → executing-plans |
| ship, release, tag, merge | review → ship |
| review, this, my, the, look at my | review → simplify |
| security, owasp, injection, secret, vuln, audit | cso → security-review |
| how does, explain, understand, what is, walk me through | graphify-query → smart-explore |
| why, did, does, is, are, what happened, root cause | investigate → mem-search |
| canary, health., check, is ., healthy, status check, deploy healthy | verification-before-completion |
| plan, design approach, strategy for, roadmap | brainstorming → writing-plans → plan-ceo-review → plan-eng-review |
| did we, last, week, time, previously, remember when | mem-search |
| office hours, narrowest wedge, product sense, yc, pmf | office-hours |
| refactor, clean, up, simplify, dedupe, duplicated | simplify |
| and also, as well as, at the same time, plus | dispatching-parallel-agents |
| and also, as well as, at the same time, plus | dispatching-parallel-agents |

## Tools

| Tool | Command | Purpose |
|------|---------|---------|
| Classifier | `superagent-classify "<task>"` | Route task to skill chain |
| Knowledge Graph | `graphify query "<question>"` | Query codebase knowledge graph |
| Memory | `mempalace search "<query>"` | Cross-session memory search |

## Non-Negotiables

- NEVER skip verification on build/fix tasks
- NEVER skip systematic debugging when a bug is mentioned
- NEVER start implementing without brainstorming or an existing plan
- ALWAYS verify your work before declaring done
