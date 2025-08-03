# Application Specifications v2
- Environment isolation: Database connection uses local default, should verify
env vars in production
- Data validation: Schema allows null/empty values that may need business logic
validation
- Indexing: May need performance indexes on frequently queried fields (user_id,
activity_id, etc.)
