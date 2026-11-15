# Supabase setup for the app

The app uses one personal account across Windows and Android. The Project URL
and publishable key are client settings; the app must never contain a database
password, `service_role` key, or secret key.

## What is prepared

- `supabase/migrations/202611150001_initial_task_sync.sql` creates the tables,
  owner-only row security, server-clock functions, and Realtime setup.
- `lib/data/supabase_task_repository.dart` writes each action to the cloud and
  returns the server's accepted row.
- `lib/data/supabase_app_config.dart` reads credentials from the ignored local
  settings file passed at app launch.

## After creating your Supabase project

1. Sign in to the Supabase Dashboard and open the project whose URL matches the
   URL in `supabase.local.json`.
2. Select **SQL Editor** in the project navigation, then choose **New query**.
3. In VS Code, open
   `supabase/migrations/202611150001_initial_task_sync.sql`, select all, and
   copy it.
4. Paste the SQL into the new Supabase query and click **Run**.
5. Wait for a success message. In the project's **Table Editor**, confirm that
   `task_lists` and `tasks` exist. The script enables row-level security and
   adds owner-only policies, server-side timer functions, and Realtime publication.

The migration creates the schema and functions; the app creates Work, Dojo, and
Home lists the first time you sign in. Running the migration does not import the
temporary sample tasks currently shown by demo mode.

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

- Stable UUIDs for lists and tasks, with database-generated add order.
- Per-account rows protected by row-level security.
- Server-clock start, pause, and completion actions for shared timers.
- Realtime notifications so another signed-in app instance can refresh rows.
- Initial Work, Dojo, and Home lists, created once for a new account.

The client uses the public publishable key. Supabase's row-level security is
what restricts access to the signed-in account.
