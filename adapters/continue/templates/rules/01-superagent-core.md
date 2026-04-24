---
name: SuperAgent Core
---
# SuperAgent Core

> Verify or die. Memory compounds. Leverage over toil.

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

## Non-Negotiables
- NEVER skip verification on build/fix tasks
- NEVER start implementing without a plan
- ALWAYS verify work before declaring done
