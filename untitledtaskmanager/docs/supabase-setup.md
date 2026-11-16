# Supabase setup for the app

The app uses one personal account across Windows and Android. The Project URL
and publishable key are client settings; the app must never contain a database
password, `service_role` key, or secret key.

## What is prepared

- `supabase/migrations/202611150001_initial_task_sync.sql` creates the tables,
  owner-only row security, server-clock functions, and Realtime setup.
- `supabase/migrations/202611150002_manual_ordering.sql` changes ordering to
  support synchronized drag-and-drop while retaining existing rows.
- `lib/data/supabase_task_repository.dart` writes each action to the cloud and
  returns the server's accepted row.
- `lib/data/supabase_app_config.dart` reads credentials from the ignored local
  settings file passed at app launch.

## Apply the ordering update to your existing project

1. Sign in to the Supabase Dashboard and open the project whose URL matches the
   URL in `supabase.local.json`.
2. Close the Windows and Chrome app windows so they are not changing data during
   the order update.
3. Select **SQL Editor** in the project navigation, then choose **New query**.
4. In VS Code, open
   `supabase/migrations/202611150002_manual_ordering.sql`, select all, and copy it.
5. Paste the SQL into the new Supabase query and click **Run**. Supabase may
   show its generic destructive-operations warning because the update removes
   the old automatic-ordering rules. This migration keeps your list/task rows
   and IDs, and sets their initial positions alphabetically (tasks alphabetically
   within each priority).
6. Wait for a success message before reopening the apps.

The first migration, `202611150001_initial_task_sync.sql`, has already been
applied to your project. Do not rerun it; this second migration updates that
existing setup.

## Start the app

The local `supabase.local.json` already contains the Project URL and publishable
key and is ignored by Git. In VS Code, select **Task Manager (Windows)** in the
Run and Debug profile picker, then start it. The first time, choose **Create a
new account**. If Supabase asks you to confirm your email, use the email link,
then return to the app and sign in.

For a first two-client sync check, keep the Windows app open and launch
`Task Manager (Chrome sync test)` from the same VS Code profile picker. Sign
into the same account in Chrome. This checks cloud sync and Realtime between two
clients; Android still needs its SDK/device setup and a later Android-specific
smoke test.

## What the migration sets up

- Stable UUIDs for lists and tasks, with synchronized drag-and-drop order.
- Per-account rows protected by row-level security.
- Server-clock start, pause, and completion actions for shared timers.
- Realtime notifications so another signed-in app instance can refresh rows.
- Initial Dojo, Home, and Work lists, created once for a new account.

The client uses the public publishable key. Supabase's row-level security is
what restricts access to the signed-in account.
