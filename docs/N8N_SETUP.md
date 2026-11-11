# n8n integration setup

LeadFlow stores each workspace's n8n webhook URL in the server-only `integration_secrets` table. The browser never writes or reads this secret directly; it uses the authenticated `/api/integrations` endpoint.

## Enter the correct URL

1. In n8n, open the **Webhook** node in the LeadFlow workflow.
2. Select **Production URL** (not Test URL).
3. Copy the complete URL. It should use HTTPS and the `/webhook/` path, for example:
   `https://YOUR-WORKSPACE.app.n8n.cloud/webhook/YOUR-PATH`
4. The hostname must exactly match the `N8N_ALLOWED_HOSTS` environment variable in the LeadFlow Vercel preview/production environment, as appropriate.
5. In LeadFlow, open **Integrations → n8n workflow automation**, paste the URL and select **Save connection**.
6. LeadFlow should report that the URL is saved but unverified. Saving checks the URL format and hostname; it does not prove that the workflow is active or that a delivery succeeded.
7. The **Automation** page displays the saved webhook URL and delivery status. Use **Manage connection** there to edit it; the **Integrations** page remains the place where the URL is saved.

Do not paste a temporary `/webhook-test/` URL. Do not paste your n8n login credentials, API key, or account password.

## If saving fails

- Confirm the URL begins with `https://`.
- Confirm the path contains `/webhook/`, not `/webhook-test/`.
- Confirm the hostname exactly matches the configured server allowlist. A different n8n workspace hostname will be rejected.
- Confirm you are signed in as the workspace owner or organization admin.
- Read the exact validation message shown by LeadFlow. Never put the full webhook URL in screenshots or public messages; it contains a unique path.

## Safe workflow verification

The current LeadFlow automation payload does **not** include an `is_test` flag. Do not build an n8n test branch that depends on that field until the LeadFlow API explicitly adds it.

Before triggering a real LeadFlow event, make sure the workflow's WhatsApp, email, SMS, and other outbound nodes cannot send messages during a test. Use a harmless no-op branch or a dedicated test workflow with outbound actions disconnected. Do not test against real customer data or recipients without explicit approval.

A URL being saved is not a successful delivery. LeadFlow must receive an actual successful response from n8n before delivery is reported as successful.

## Event contract

The production integration uses a server-side proxy. Keep payloads minimal and use an idempotency key for every event. Do not treat the webhook URL as a browser-side secret.

No email, SMS, WhatsApp or other notification is claimed as delivered unless its provider confirms delivery.
