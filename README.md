# Nanga

Nanga is a macOS app for agent workflows.

Its job is to keep each iteration anchored to the current task by pulling live signal from the work in front of you, selecting only the context that still matters, executing inside the right scope, and carrying forward only validated state into the next iteration.

Most agent workflows drift because they accumulate too much context, lose track of what is actually in scope, and force developers to restate the same task over and over. Nanga is built to reduce that drift.

## What Nanga Is About

Nanga is designed around a tight iteration loop:

1. identify the current task
2. extract the minimum signal required to act
3. define the active scope before execution
4. run inside that scope
5. inspect the resulting state
6. refresh context from what changed
7. preserve only what still matters for the next iteration

The goal is not to dump more context into an agent. The goal is to make context smaller, fresher, and more trustworthy.

Nanga should help developers:

- reduce repeated context dumping
- keep execution constrained to the relevant surface
- preserve momentum across iterations
- make scope visible before execution
- make resulting state legible after execution
- resume work without rebuilding context manually

## Open Source and Paid Product

Nanga is intended to be both an open-source concept and a paid macOS product.

The open-source GitHub repository should make the core idea real and inspectable. It can include the architecture, signal model, workflow philosophy, and selected core implementation pieces so people can understand how Nanga works and build on the underlying approach.

The paid macOS app is the polished operator surface. That is where the product experience lives: project management, task input, signal and scope panels, saved iteration state, refresh flows, integrated agent workflows, exports, and the UI/UX work that makes Nanga feel reliable in day-to-day use.

In short:

- open source explains the model and exposes core building blocks
- the macOS app delivers the premium workflow experience

This split keeps the idea open while making the product worth paying for.

## What Belongs in the GitHub Repo

The repository can responsibly expose:

- the workflow philosophy behind scoped agent execution
- the signal and scope model
- architecture and implementation details
- core runtime or engine pieces
- a CLI or basic execution surface
- enough real implementation to prove the system is not conceptual vapor

The repo should help people understand:

- how Nanga reduces drift
- how scope is derived
- how refresh should work after execution
- how useful iteration state can be preserved without keeping stale context

## What To Borrow, What To Avoid

Nanga can learn useful lessons from agent frameworks such as `Swarm`, but it should stay narrower and more product-driven.

What to borrow:

- a structured workspace contract for instructions, skills, memory, and iteration artifacts
- validation before execution so malformed state is caught early
- resumable iteration state instead of fragile one-shot runs
- deterministic scenario testing for run, refresh, carry-forward, and resume behavior
- Swift-native runtime discipline

What to avoid:

- turning Nanga into a broad orchestration framework
- adding workflow modes and provider abstractions before the core app loop is excellent
- expanding memory and agent features faster than the product can make them legible

Nanga should borrow runtime rigor, not framework sprawl.

## What People Pay For

The paid macOS app should be the best way to actually use Nanga.

That includes:

- polished project and workspace management
- a high-quality task input flow
- signal and scope panels that make execution boundaries obvious
- saved iteration state that makes resuming frictionless
- visual refresh and resulting-state inspection
- agent integrations and productized runtime behavior
- refined macOS-native UX, performance, and reliability

The value is not just raw functionality. The value is a tool that feels tight, dependable, and fast enough to stay in the loop every day.

## Product Direction

Nanga is opinionated about how agent workflows should work:

- scope should be visible before execution
- only current signal should shape the next action
- resulting state should be easier to understand than the raw execution trace
- iteration memory should be structured, not dumped
- developers should not need to reconstruct context on every pass

If a feature adds ceremony, broadens scope without explanation, or preserves stale state, it is probably moving Nanga in the wrong direction.

## Status

This repository contains the foundations of Nanga as it is being built. The long-term direction is an open core around scoped agent execution and a paid macOS app that turns that core into a polished daily workflow tool.
