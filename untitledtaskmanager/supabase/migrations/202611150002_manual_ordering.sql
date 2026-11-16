-- Keep each app client's custom list/task order in Supabase.
-- Existing rows are retained; the first application of this migration changes
-- their starting order to alphabetical within each requested sort group.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'task_lists'
      and column_name = 'sort_order'
      and is_identity = 'YES'
  ) then
    alter table public.task_lists alter column sort_order drop identity if exists;
    alter table public.task_lists
      drop constraint if exists task_lists_owner_id_sort_order_key;

    with ranked as (
      select id,
             row_number() over (
               partition by owner_id order by pg_catalog.lower(name), id
             ) - 1 as new_order
      from public.task_lists
    )
    update public.task_lists as lists
       set sort_order = ranked.new_order
      from ranked
     where lists.id = ranked.id;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'tasks'
      and column_name = 'sort_order'
      and is_identity = 'YES'
  ) then
    alter table public.tasks alter column sort_order drop identity if exists;

    with ranked as (
      select id,
             row_number() over (
               partition by owner_id, list_id, priority
               order by pg_catalog.lower(title), id
             ) - 1 as new_order
      from public.tasks
    )
    update public.tasks as tasks
       set sort_order = ranked.new_order
      from ranked
     where tasks.id = ranked.id;
  end if;
end;
$$;

alter table public.task_lists
  add column if not exists manually_ordered boolean not null default false;
alter table public.task_lists
  add column if not exists custom_task_priorities smallint[] not null default '{}';

do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_constraint
     where conrelid = 'public.task_lists'::regclass
       and conname = 'task_lists_owner_sort_order_unique'
  ) then
    alter table public.task_lists
      add constraint task_lists_owner_sort_order_unique
      unique (owner_id, sort_order) deferrable initially deferred;
  end if;

  if not exists (
    select 1 from pg_catalog.pg_constraint
     where conrelid = 'public.tasks'::regclass
       and conname = 'tasks_owner_group_sort_order_unique'
  ) then
    alter table public.tasks
      add constraint tasks_owner_group_sort_order_unique
      unique (owner_id, list_id, priority, sort_order) deferrable initially deferred;
  end if;
end;
$$;

-- New accounts still get the three starter lists, now in alphabetical order.
create or replace function public.ensure_default_task_lists()
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Sign in is required'; end if;

  if not exists (
    select 1 from public.task_lists where owner_id = auth.uid()
  ) then
    insert into public.task_lists
      (id, owner_id, name, icon_key, sort_order)
    values
      (pg_catalog.gen_random_uuid(), auth.uid(), 'Dojo', 'karate', 0),
      (pg_catalog.gen_random_uuid(), auth.uid(), 'Home', 'home', 1),
      (pg_catalog.gen_random_uuid(), auth.uid(), 'Work', 'work', 2)
    on conflict do nothing;
  end if;
end;
$$;
revoke all on function public.ensure_default_task_lists() from public;
grant execute on function public.ensure_default_task_lists() to authenticated;

create or replace function public.create_task_list(
  p_id uuid, p_name text, p_icon_key text
)
returns public.task_lists
language plpgsql
security invoker
set search_path = ''
as $$
declare
  saved public.task_lists;
  ordered_manually boolean;
  new_order bigint;
begin
  if auth.uid() is null then raise exception 'Sign in is required'; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(auth.uid()::text, 0)
  );

  select coalesce(pg_catalog.bool_or(manually_ordered), false)
    into ordered_manually
    from public.task_lists
   where owner_id = auth.uid();

  if ordered_manually then
    select coalesce(pg_catalog.max(sort_order), -1) + 1
      into new_order from public.task_lists where owner_id = auth.uid();
  else
    with ranked as (
      select id,
             row_number() over (
               partition by owner_id order by pg_catalog.lower(name), id
             ) - 1 as new_order
      from public.task_lists
      where owner_id = auth.uid()
    )
    update public.task_lists as lists
       set sort_order = ranked.new_order
      from ranked
     where lists.id = ranked.id;

    select pg_catalog.count(*) into new_order
      from public.task_lists
     where owner_id = auth.uid()
       and pg_catalog.lower(name) < pg_catalog.lower(pg_catalog.btrim(p_name));

    update public.task_lists
       set sort_order = sort_order + 1
     where owner_id = auth.uid() and sort_order >= new_order;
  end if;

  insert into public.task_lists
    (id, owner_id, name, icon_key, sort_order, manually_ordered)
  values
    (p_id, auth.uid(), pg_catalog.btrim(p_name), p_icon_key, new_order, ordered_manually)
  returning * into saved;
  return saved;
end;
$$;
revoke all on function public.create_task_list(uuid, text, text) from public;
grant execute on function public.create_task_list(uuid, text, text) to authenticated;

create or replace function public.update_task_list(
  p_id uuid, p_name text, p_icon_key text
)
returns public.task_lists
language plpgsql
security invoker
set search_path = ''
as $$
declare
  saved public.task_lists;
  ordered_manually boolean;
begin
  if auth.uid() is null then raise exception 'Sign in is required'; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(auth.uid()::text, 0)
  );

  select manually_ordered into ordered_manually
    from public.task_lists
   where id = p_id and owner_id = auth.uid()
   for update;
  if not found then raise exception 'List not found'; end if;

  update public.task_lists
     set name = pg_catalog.btrim(p_name), icon_key = p_icon_key
   where id = p_id and owner_id = auth.uid();

  if not ordered_manually then
    with ranked as (
      select id,
             row_number() over (
               partition by owner_id order by pg_catalog.lower(name), id
             ) - 1 as new_order
      from public.task_lists
      where owner_id = auth.uid()
    )
    update public.task_lists as lists
       set sort_order = ranked.new_order
      from ranked
     where lists.id = ranked.id;
  end if;

  select * into saved from public.task_lists
   where id = p_id and owner_id = auth.uid();
  return saved;
end;
$$;
revoke all on function public.update_task_list(uuid, text, text) from public;
grant execute on function public.update_task_list(uuid, text, text) to authenticated;

create or replace function public.reorder_task_lists(p_list_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  expected_count bigint;
  supplied_count bigint;
  matched_count bigint;
begin
  if auth.uid() is null then raise exception 'Sign in is required'; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(auth.uid()::text, 0)
  );

  select pg_catalog.count(*) into expected_count
    from public.task_lists where owner_id = auth.uid();
  select pg_catalog.count(distinct item_id) into supplied_count
    from pg_catalog.unnest(coalesce(p_list_ids, '{}'::uuid[])) as item(item_id);
  select pg_catalog.count(*) into matched_count
    from pg_catalog.unnest(coalesce(p_list_ids, '{}'::uuid[])) as item(item_id)
    join public.task_lists as lists
      on lists.id = item.item_id and lists.owner_id = auth.uid();
  if supplied_count <> expected_count
     or matched_count <> expected_count
     or pg_catalog.cardinality(coalesce(p_list_ids, '{}'::uuid[])) <> expected_count then
    raise exception 'The submitted order must contain every list exactly once';
  end if;

  update public.task_lists as lists
     set sort_order = submitted.position - 1,
         manually_ordered = true
    from pg_catalog.unnest(p_list_ids) with ordinality as submitted(id, position)
   where lists.id = submitted.id and lists.owner_id = auth.uid();
end;
$$;
revoke all on function public.reorder_task_lists(uuid[]) from public;
grant execute on function public.reorder_task_lists(uuid[]) to authenticated;

create or replace function public.create_task(
  p_task_id uuid, p_list_id uuid, p_title text, p_priority smallint
)
returns public.tasks
language plpgsql
security invoker
set search_path = ''
as $$
declare
  saved public.tasks;
  group_is_custom boolean;
  new_order bigint;
begin
  if auth.uid() is null then raise exception 'Sign in is required'; end if;
  if p_priority < 1 or p_priority > 5 then raise exception 'Invalid priority'; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_list_id::text || ':' || p_priority::text, 0)
  );

  select p_priority = any(custom_task_priorities)
    into group_is_custom
    from public.task_lists
   where id = p_list_id and owner_id = auth.uid();
  if not found then raise exception 'List not found'; end if;

  if group_is_custom then
    select coalesce(pg_catalog.max(sort_order), -1) + 1
      into new_order from public.tasks
     where owner_id = auth.uid() and list_id = p_list_id and priority = p_priority;
  else
    with ranked as (
      select id,
             row_number() over (
               partition by owner_id, list_id, priority
               order by pg_catalog.lower(title), id
             ) - 1 as new_order
      from public.tasks
      where owner_id = auth.uid()
        and list_id = p_list_id
        and priority = p_priority
    )
    update public.tasks as tasks
       set sort_order = ranked.new_order
      from ranked
     where tasks.id = ranked.id;

    select pg_catalog.count(*) into new_order
      from public.tasks
     where owner_id = auth.uid() and list_id = p_list_id and priority = p_priority
       and (pg_catalog.lower(title) < pg_catalog.lower(pg_catalog.btrim(p_title))
         or (pg_catalog.lower(title) = pg_catalog.lower(pg_catalog.btrim(p_title))
             and id < p_task_id));

    update public.tasks
       set sort_order = sort_order + 1
     where owner_id = auth.uid() and list_id = p_list_id
       and priority = p_priority and sort_order >= new_order;
  end if;

  insert into public.tasks
    (id, owner_id, list_id, title, priority, sort_order)
  values
    (p_task_id, auth.uid(), p_list_id, pg_catalog.btrim(p_title), p_priority, new_order)
  returning * into saved;
  return saved;
end;
$$;
revoke all on function public.create_task(uuid, uuid, text, smallint) from public;
grant execute on function public.create_task(uuid, uuid, text, smallint) to authenticated;

create or replace function public.reorder_tasks(
  p_list_id uuid, p_priority smallint, p_task_ids uuid[]
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  expected_count bigint;
  supplied_count bigint;
  matched_count bigint;
begin
  if auth.uid() is null then raise exception 'Sign in is required'; end if;
  if p_priority < 1 or p_priority > 5 then raise exception 'Invalid priority'; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_list_id::text || ':' || p_priority::text, 0)
  );

  if not exists (
    select 1 from public.task_lists
     where id = p_list_id and owner_id = auth.uid()
  ) then raise exception 'List not found'; end if;

  select pg_catalog.count(*) into expected_count
    from public.tasks
   where owner_id = auth.uid() and list_id = p_list_id and priority = p_priority;
  select pg_catalog.count(distinct task_id) into supplied_count
    from pg_catalog.unnest(coalesce(p_task_ids, '{}'::uuid[])) as item(task_id);
  select pg_catalog.count(*) into matched_count
    from pg_catalog.unnest(coalesce(p_task_ids, '{}'::uuid[])) as item(task_id)
    join public.tasks as tasks
      on tasks.id = item.task_id
     and tasks.owner_id = auth.uid()
     and tasks.list_id = p_list_id
     and tasks.priority = p_priority;
  if supplied_count <> expected_count
     or matched_count <> expected_count
     or pg_catalog.cardinality(coalesce(p_task_ids, '{}'::uuid[])) <> expected_count then
    raise exception 'The submitted order must contain every task in this priority exactly once';
  end if;

  update public.tasks as tasks
     set sort_order = submitted.position - 1
    from pg_catalog.unnest(p_task_ids) with ordinality as submitted(id, position)
   where tasks.id = submitted.id and tasks.owner_id = auth.uid()
     and tasks.list_id = p_list_id and tasks.priority = p_priority;

  update public.task_lists
     set custom_task_priorities = case
       when p_priority = any(custom_task_priorities) then custom_task_priorities
       else pg_catalog.array_append(custom_task_priorities, p_priority)
     end
   where id = p_list_id and owner_id = auth.uid();
end;
$$;
revoke all on function public.reorder_tasks(uuid, smallint, uuid[]) from public;
grant execute on function public.reorder_tasks(uuid, smallint, uuid[]) to authenticated;
