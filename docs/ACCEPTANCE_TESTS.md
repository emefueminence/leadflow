# Acceptance checklist

Do not mark an item passed unless it was actually verified.

- [ ] App opens without runtime error
- [ ] Main navigation works
- [ ] Lead creation works
- [ ] Demo lead persists after refresh
- [ ] Lead edit/delete works
- [ ] Search and filters are correct
- [ ] CSV contains relevant fields
- [ ] Dashboard metrics update
- [ ] Required-field validation is understandable
- [ ] Duplicate contacts trigger a warning
- [ ] Overdue follow-up is grouped correctly
- [ ] App works without an AI key
- [ ] AI failure cannot destroy/duplicate leads
- [ ] AI content is marked as generated/draft
- [ ] n8n reports real results only
- [ ] Demo controls protect non-demo records
- [ ] Mobile layout remains usable
- [ ] No private key is exposed in frontend code
- [ ] Unconfigured integrations show instructions
- [ ] Documented build/start commands work

## Known rebuild-v2 limitation
The branch is still in demo/local-storage mode while shared database and authentication are implemented.
