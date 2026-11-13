"""Deterministic agronomic science.

This package is the one place equations are allowed to live. Everything
here is a pure function: no FastAPI, no HTTP, no database, no LLM. Given
the same inputs it returns the same outputs, so a judge (or a future
regression test) can re-run any advisory response by hand.

`app/modules/advisory/service.py` calls into this package and does not
duplicate any equation; it only assembles evidence and provenance around
what these functions compute.
"""
