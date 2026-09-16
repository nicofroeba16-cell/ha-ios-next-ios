# Project Dispatch Contract

Owner-approved tickets are converted into project work orders only after explicit approval.

## Project IDs

- ios-app -> iOS App (nicofroeba16-cell/ha-ios-next-ios)
- fire-tv -> Fire TV Companion (nicofroeba16-cell/AmazonTV-App)
- ha-dashboard -> Home Assistant Dashboard (nicofroeba16-cell/HA-CONFIG)
- intelligence-suite -> Intelligence Suite (nicofroeba16-cell/Intelligence-Suite-)
- file-bridge -> File Bridge (nicofroeba16-cell/File-Bridge-mcp)
- ha-simulation -> HA Simulation
- global-health -> Global Project Health
- general -> manual triage

## Approval flow

1. A non-owner creates a support ticket.
2. The server proposes a project using deterministic ticket-content matching.
3. The owner reviews the ticket and can change the proposed project.
4. Only POST /v1/admin/tickets/<id>/approve can create a dispatch.
5. The backend writes an atomic JSON work order to project-queue/<project-id>/.
6. A project worker may consume only completed .json files, never .tmp files.
7. Recognizable secrets/credentials are rejected before ticket persistence and checked again before dispatch.
8. A repeated approval for the same project is idempotent and repairs a missing queue file; a different project conflicts.

A normal chat token cannot approve or dispatch a ticket.

## Work-order schema

Each JSON work order contains:

- schema_version
- dispatch_id
- ticket_id
- project.id, project.title, optional project.repository
- approved_by
- approved_at
- the complete approved ticket conversation
- a processing instruction

The queue is deliberately separate from the ephemeral E2EE chat. Ticket/work-order contents are persistent.
