# Secret Owner Admin API

The hidden entry gesture is only a discovery barrier. Security is enforced by all of the following:

1. Face ID using `deviceOwnerAuthenticationWithBiometrics` without passcode fallback.
2. An owner token stored only in Keychain.
3. Server verification that `GET /v1/admin/session` returns `role: "owner"`.
4. Fresh biometric authorization before every mutating maintenance action.
5. Server-side allowlisted operations and an immutable audit trail.

The admin service must not implement an arbitrary shell endpoint.

## Endpoints

- `GET /v1/admin/session`
- `GET /v1/admin/status`
- `GET /v1/admin/audit?limit=50`
- `POST /v1/admin/actions/health-check`
- `POST /v1/admin/actions/maintenance-enable`
- `POST /v1/admin/actions/maintenance-disable`
- `POST /v1/admin/actions/reconnect-sessions`
- `POST /v1/admin/actions/clear-cache`
- `POST /v1/admin/actions/rotate-logs`
- `POST /v1/admin/actions/create-backup`

The owner entry is opened by tapping the `iOS 27` value seven times on the app information screen. Knowing this gesture grants no authorization.


## Owner ticket channel

Support tickets are deliberately separate from the ephemeral E2EE chat.

- GET /v1/admin/tickets?limit=100
- GET /v1/admin/tickets/<ticket-id>
- POST /v1/admin/tickets/<ticket-id>/messages
- POST /v1/admin/tickets/<ticket-id>/status

These endpoints require the owner token. Ticket replies from the Owner UI therefore cannot be authorized with a normal chat token. The Owner UI remains protected by the existing server-side owner session and local Face ID gate.

Ticket states are open, in_progress, and resolved.


## Owner-approved project routing

An incoming member ticket never starts project work by itself. Only the owner can dispatch it.

- GET /v1/admin/projects
- GET /v1/admin/dispatches?limit=100
- POST /v1/admin/tickets/<ticket-id>/approve with {"project_id":"..."}

Approval is idempotent for the same project and conflicts if the same ticket is later pointed at a different project. A successful approval:

1. records the owner identity and approval timestamp,
2. sets the ticket status to approved,
3. creates exactly one persistent project dispatch,
4. writes an atomic work-order JSON file under admin-state/project-queue/<project-id>/.

The project suggestion is advisory only. The Owner UI lets the owner change the project before approving.
