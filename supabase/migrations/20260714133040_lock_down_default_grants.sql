
-- Strip the overly broad default grants Supabase applies to new tables, and replace with
-- explicit least-privilege access. service_role is untouched (bypasses RLS/grants entirely,
-- used only inside Edge Functions with the service key, never shipped to the client).

revoke all on public.words from anon, authenticated;
grant select on public.words to anon, authenticated;

revoke all on public.daily_puzzles from anon, authenticated;
grant select on public.daily_puzzles to anon, authenticated;
-- (RLS policy "public metadata visible for today or past puzzles" still gates which rows
--  are actually readable; this grant only makes SELECT possible at all, INSERT/UPDATE/DELETE/
--  TRUNCATE are no longer grantable to these roles.)

revoke all on public.daily_puzzle_public from anon, authenticated;
grant select on public.daily_puzzle_public to anon, authenticated;

-- Also lock down default privileges for anything created in this schema going forward,
-- so future tables don't silently inherit the same overly broad defaults.
alter default privileges in schema public
  revoke all on tables from anon, authenticated;
