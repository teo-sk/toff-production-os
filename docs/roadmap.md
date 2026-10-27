# Roadmap

Production OS **0.3.0** adds the Unity tooling abstraction and capability detection after Nehokej, WheelDraw, and SOWA pilots. It remains intentionally incomplete relative to a full orchestrator.

## Near term

- Bootstrap additional dissimilar games and capture exceptions.  
- Re-verify CLI capability maps when Unity CLI / Pipeline versions change.  
- Tighten validate.sh adapters from real CI feedback.  
- Optional shared PR checklist snippet.

## Medium term

- CI workflow templates (GitHub Actions / other) with Unity licensing hooks as **adapters**.  
- Release-candidate checklist automation (metadata only — no auto-publish).  
- Versioned template upgrade helper (`bootstrap --upgrade` with three-way guidance).  
- Headless-first **TOFF Game Development Orchestrator** consuming the Unity Tooling Contract.

## Later / deferred

- Event-driven multi-agent orchestration beyond the orchestrator MVP  
- Portfolio dashboard and cost metrics  
- Shared art token libraries  
- Store submission automation  
- Unattended Editor mutations without human approval  

## Explicit non-goals for 0.3.x

- Building the orchestrator inside this milestone  
- Autonomous game design without human gates  
- One shared Unity package mono-repo for all titles  
- Requiring Unity CLI, Pipeline, or MCP for every task  
- Automatic MCP migration or automatic Editor force-quit  
