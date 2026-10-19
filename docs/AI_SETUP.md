# AI configuration

LeadFlow must remain usable when AI is not configured.

Connected mode will call Gemini from a server-side endpoint using `GEMINI_API_KEY`. The browser must never receive the key.

Expected validated result:

```json
{
  "category": "buy | rent | sell | general",
  "priority": "high | medium | low",
  "summary": "Short factual summary",
  "suggested_reply": "Draft response requiring human review",
  "missing_information": ["Relevant missing details"]
}
```

Rules:
- Priority reflects explicit urgency, not budget size.
- Never invent properties, prices, discounts, legal advice, appointments or agency policies.
- AI text is a draft for human review and is never auto-sent.
- Malformed output, timeout or provider failure must not destroy or duplicate a lead.
- Without a key, show AI as unconfigured or use only the clearly labelled deterministic demo fallback.
