# Journal — Milestone 0: Foundations

Write short answers in your own words. Replace every TODO.
These notes become the explanations other people read later.

## Task 1 — what I saw with plain Docker

- `docker run ... platform.machine()` printed: TODO — why does it say aarch64 even though you never chose an architecture?
- What `-p 8099:8000` did: TODO
- What `hostname` inside the container printed, and why it isn't your Mac's name: TODO
- After `docker rm -f web`, where did the container's files go? TODO

## Concepts

- Image vs container, in one sentence: TODO
- Why pin `python:3.12-slim` instead of `python:latest`? TODO
- Bind mount vs named volume — when would you use each? TODO
- In the healthcheck, why `localhost:8000` and not `HELLO_PORT`? TODO
- What does a Compose profile let someone with an 8 GB Mac do? TODO
- In a Makefile, why write `$$ans` instead of `$ans`? TODO

## Break-it experiments

| Experiment | What happened | Why |
|---|---|---|
| TODO | TODO | TODO |
| TODO | TODO | TODO |
| TODO | TODO | TODO |

## Databricks connection

- Which part of today's setup plays the role of the Databricks Runtime? Of DBFS? TODO

## Decisions I made (and why)

- Docker runtime chosen: TODO, because TODO
- HELLO_PORT chosen: TODO
