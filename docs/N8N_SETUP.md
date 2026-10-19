# n8n integration contract

The production integration will use a server-side proxy. The webhook URL must not be treated as a browser-side secret.

## Event
`lead.created` or an explicit user-triggered automation.

## Minimal payload

```json
{
  "event": "lead.created",
  "event_id": "unique-idempotency-key",
  "lead_id": "LF-1234",
  "timestamp": "ISO-8601 timestamp",
  "lead": {
    "source": "Website",
    "category": "Renting",
    "property_type": "Apartment",
    "preferred_location": "Lekki",
    "budget": "₦3m/year",
    "timeline": "Next month",
    "enquiry_text": "Customer enquiry"
  }
}
```

Send only fields needed by the workflow. Add timeouts and surface the actual latest success/failure result. Retries must reuse the same event ID so duplicate actions can be avoided.

No email, SMS, WhatsApp or other notification is claimed as delivered unless its provider confirms delivery.
