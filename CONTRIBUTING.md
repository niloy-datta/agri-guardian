# Mukti Development Rules

- Architecture: Flutter → FastAPI → PostgreSQL/PostGIS.
- Supabase is authentication only unless explicitly stated otherwise.
- NASA/Copernicus and other external providers are backend-only.
- Preserve existing working code.
- One scoped implementation phase per commit.
- Never invent NASA, weather, risk, or intelligence values.
- Never claim a test passed unless it actually ran.
- Inspect relevant code before making claims.
- Modify only files allowed by the active task.
- Check `git diff --name-only` before finishing.
- Do not implement future phases early.

## Backend

- Keep business rules in the service layer and database access in the repository layer.
- PostgreSQL/PostGIS is the source of truth; Redis is not.
- Use Alembic for schema changes and preserve migration history.
- Run Ruff, MyPy, and Pytest for backend changes.

## Earth observation

- Access external Earth observation services from the backend.
- Use the full field polygon instead of a center pixel.
- Preserve provider, dataset, time, resolution, quality, and provenance.
- Never fabricate measurements or claim NASA directly diagnoses plant disease.
- Preserve uncertainty and insufficient evidence states; avoid false spatial precision.

## Flutter

- Use Riverpod and go_router.
- Fetch domain data through FastAPI; use Supabase for authentication.
- Preserve working UI unless the task changes its design.
- Never display fabricated intelligence values.
- Run `flutter analyze` and `flutter test` for Flutter changes.
