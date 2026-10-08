create extension if not exists pgcrypto;

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  slug text not null unique,
  type text not null,
  logo_url text,
  cover_url text,
  description text,
  phone text,
  email text,
  address text,
  city text,
  country text not null default 'Nigeria',
  currency text not null default 'NGN',
  status text not null default 'DRAFT' check (status in ('DRAFT','PUBLISHED','SUSPENDED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.memberships (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('OWNER','MANAGER','STAFF')),
  status text not null default 'ACTIVE' check (status in ('INVITED','ACTIVE','SUSPENDED','REMOVED')),
  created_at timestamptz not null default now(),
  unique(business_id,user_id)
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  description text,
  price numeric(14,2) not null default 0 check (price >= 0),
  image_url text,
  category text,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','INACTIVE','ARCHIVED')),
  track_stock boolean not null default false,
  stock_quantity integer check (stock_quantity is null or stock_quantity >= 0),
  low_stock_threshold integer check (low_stock_threshold is null or low_stock_threshold >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  location_type text not null default 'OTHER' check (location_type in ('TABLE','ROOM','APARTMENT','OFFICE','CAMPUS_ROOM','STORE','OTHER')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  name text not null,
  phone text not null,
  email text,
  created_at timestamptz not null default now(),
  unique(business_id,phone)
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_id uuid references public.customers(id) on delete set null,
  customer_user_id uuid references auth.users(id) on delete set null,
  customer_name text not null,
  customer_phone text not null,
  customer_email text,
  fulfillment text not null default 'ON_PREMISE' check (fulfillment in ('ON_PREMISE','PICKUP','DELIVERY')),
  location_id uuid references public.locations(id) on delete set null,
  status text not null default 'PENDING_PAYMENT' check (status in ('PENDING_PAYMENT','NEW','CONFIRMED','PREPARING','READY','READY_FOR_PICKUP','COMPLETED','CANCELLED','REFUNDED')),
  payment_status text not null default 'PENDING' check (payment_status in ('PENDING','PROCESSING','PAID','FAILED','CANCELLED','REFUNDED')),
  subtotal numeric(14,2) not null check (subtotal >= 0),
  total numeric(14,2) not null check (total >= 0),
  public_token text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  name_snapshot text not null,
  unit_price numeric(14,2) not null check (unit_price >= 0),
  quantity integer not null check(quantity > 0),
  line_total numeric(14,2) not null check (line_total >= 0)
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  business_id uuid references public.businesses(id) on delete cascade,
  action text not null,
  entity_type text,
  entity_id uuid,
  metadata jsonb,
  created_at timestamptz not null default now()
);


create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  type text not null,
  title text not null,
  message text not null,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  price numeric(14,2) not null default 0 check(price >= 0),
  currency text not null default 'NGN',
  interval text not null default 'MONTHLY' check(interval in ('MONTHLY','YEARLY','ONE_TIME')),
  trial_days integer not null default 0 check(trial_days >= 0),
  features jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.business_subscriptions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null unique references public.businesses(id) on delete cascade,
  plan_id uuid not null references public.subscription_plans(id),
  status text not null default 'TRIAL' check(status in ('TRIAL','ACTIVE','PAST_DUE','EXPIRED','CANCELLED')),
  provider text,
  provider_reference text,
  started_at timestamptz not null default now(),
  trial_ends_at timestamptz,
  current_period_start timestamptz,
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


insert into public.subscription_plans(code,name,description,price,currency,interval,trial_days,features)
values
('STARTER','Starter','Launch your digital storefront.',0,'NGN','MONTHLY',14,'{"products":50,"locations":3,"staff":1,"analytics":false}'),
('GROWTH','Growth','For growing businesses.',15000,'NGN','MONTHLY',0,'{"products":500,"locations":20,"staff":5,"analytics":true}'),
('SCALE','Scale','For larger operations.',50000,'NGN','MONTHLY',0,'{"products":5000,"locations":100,"staff":25,"analytics":true}')
on conflict (code) do update set name=excluded.name,description=excluded.description,price=excluded.price,currency=excluded.currency,interval=excluded.interval,trial_days=excluded.trial_days,features=excluded.features;

create index if not exists products_business_status_idx on public.products(business_id,status);
create index if not exists orders_business_created_idx on public.orders(business_id,created_at desc);
create unique index if not exists orders_public_token_idx on public.orders(public_token) where public_token is not null;
create index if not exists memberships_user_idx on public.memberships(user_id,status);

create or replace function public.is_business_member(bid uuid) returns boolean
language sql security definer set search_path=public stable as $$
  select exists(select 1 from public.memberships where business_id=bid and user_id=auth.uid() and status='ACTIVE');
$$;

create or replace function public.is_business_manager(bid uuid) returns boolean
language sql security definer set search_path=public stable as $$
  select exists(select 1 from public.memberships where business_id=bid and user_id=auth.uid() and status='ACTIVE' and role in ('OWNER','MANAGER'));
$$;

alter table public.businesses enable row level security;
alter table public.memberships enable row level security;
alter table public.products enable row level security;
alter table public.locations enable row level security;
alter table public.customers enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.audit_logs enable row level security;
alter table public.notifications enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.business_subscriptions enable row level security;

-- Drop/recreate policies so this migration is safe to re-run during development.
drop policy if exists "owners manage own business" on public.businesses;
drop policy if exists "public read published businesses" on public.businesses;
drop policy if exists "members read membership" on public.memberships;
drop policy if exists "owners manage membership" on public.memberships;
drop policy if exists "members manage products" on public.products;
drop policy if exists "public read active products" on public.products;
drop policy if exists "members manage locations" on public.locations;
drop policy if exists "public read active locations" on public.locations;
drop policy if exists "members manage customers" on public.customers;
drop policy if exists "members read orders" on public.orders;
drop policy if exists "members update orders" on public.orders;
drop policy if exists "members read items" on public.order_items;
drop policy if exists "members audit" on public.audit_logs;

create policy "owners manage own business" on public.businesses for all using (owner_id=auth.uid()) with check (owner_id=auth.uid());
create policy "public read published businesses" on public.businesses for select using (status='PUBLISHED');

create policy "members read membership" on public.memberships for select using (user_id=auth.uid() or public.is_business_member(business_id));
create policy "owners manage membership" on public.memberships for all using (exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=auth.uid())) with check (exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=auth.uid()));

create policy "public read active products" on public.products for select using (exists(select 1 from public.businesses b where b.id=business_id and b.status='PUBLISHED') and status='ACTIVE');

create policy "public read active locations" on public.locations for select using (active=true and exists(select 1 from public.businesses b where b.id=business_id and b.status='PUBLISHED'));

create policy "members read orders" on public.orders for select using (public.is_business_member(business_id) or customer_user_id=auth.uid());

create policy "members read items" on public.order_items for select using (exists(select 1 from public.orders o where o.id=order_id and (o.customer_user_id=auth.uid() or public.is_business_member(o.business_id))));


drop policy if exists "members read notifications" on public.notifications;
create policy "members read notifications" on public.notifications
  for select using (public.is_business_member(business_id));

drop policy if exists "public read active subscription plans" on public.subscription_plans;
create policy "public read active subscription plans" on public.subscription_plans
  for select using (active=true);

drop policy if exists "members read subscription" on public.business_subscriptions;
create policy "members read subscription" on public.business_subscriptions
  for select using (public.is_business_member(business_id));

-- Public order creation is intentionally not exposed as a raw INSERT policy.
-- Checkout must use a server-side/RPC order-creation flow that recalculates prices from products.

-- Secure public checkout: the client submits product IDs and quantities only.
-- Prices, availability, business ownership and stock are recalculated server-side.
-- Payment records and verified settlement state.
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  provider text not null,
  provider_reference text not null unique,
  amount numeric(14,2) not null check(amount >= 0),
  currency text not null default 'NGN',
  status text not null default 'PENDING' check(status in ('PENDING','PROCESSING','PAID','FAILED','CANCELLED','REFUNDED')),
  authorization_url text,
  paid_at timestamptz,
  metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists payments_business_created_idx on public.payments(business_id,created_at desc);
create index if not exists payments_order_idx on public.payments(order_id);
create unique index if not exists payments_active_order_idx on public.payments(order_id) where status in ('PENDING','PROCESSING');
alter table public.payments enable row level security;
drop policy if exists "members read payments" on public.payments;
create policy "members read payments" on public.payments for select using (public.is_business_member(business_id));

-- Replace the checkout function so unpaid orders do not consume stock.
drop function if exists public.create_public_order(text,text,text,text,uuid,jsonb);
create or replace function public.create_public_order(
  p_slug text,p_customer_name text,p_customer_phone text,p_customer_email text default null,
  p_location_id uuid default null,p_items jsonb default '[]'::jsonb
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_business businesses%rowtype;v_customer_id uuid;v_order_id uuid;v_token text;v_subtotal numeric(14,2):=0;v_item jsonb;v_product products%rowtype;v_qty integer;v_line numeric(14,2);
begin
 if length(trim(p_customer_name))<2 or length(trim(p_customer_phone))<7 then raise exception 'Valid customer name and phone are required'; end if;
 select * into v_business from businesses where slug=lower(trim(p_slug)) and status='PUBLISHED' limit 1;if not found then raise exception 'Storefront is unavailable';end if;
 if jsonb_array_length(p_items)=0 then raise exception 'Cart is empty';end if;
 if p_location_id is not null and not exists(select 1 from locations where id=p_location_id and business_id=v_business.id and active=true) then raise exception 'Invalid location';end if;
 v_token:=encode(gen_random_bytes(18),'hex');
 insert into customers(business_id,name,phone,email) values(v_business.id,trim(p_customer_name),trim(p_customer_phone),nullif(trim(coalesce(p_customer_email,'')),'')) on conflict(business_id,phone) do update set name=excluded.name,email=coalesce(excluded.email,customers.email) returning id into v_customer_id;
 insert into orders(business_id,customer_id,customer_name,customer_phone,customer_email,fulfillment,location_id,status,payment_status,subtotal,total,public_token) values(v_business.id,v_customer_id,trim(p_customer_name),trim(p_customer_phone),nullif(trim(coalesce(p_customer_email,''))),'ON_PREMISE',p_location_id,'PENDING_PAYMENT','PENDING',0,0,v_token) returning id into v_order_id;
 for v_item in select * from jsonb_array_elements(p_items) loop
  v_qty:=greatest(1,(v_item->>'quantity')::integer);
  select * into v_product from products where id=(v_item->>'product_id')::uuid and business_id=v_business.id and status='ACTIVE';
  if not found then raise exception 'One or more products are unavailable';end if;
  if v_product.track_stock and coalesce(v_product.stock_quantity,0)<v_qty then raise exception 'Not enough stock for %',v_product.name;end if;
  v_line:=v_product.price*v_qty;v_subtotal:=v_subtotal+v_line;
  insert into order_items(order_id,product_id,name_snapshot,unit_price,quantity,line_total) values(v_order_id,v_product.id,v_product.name,v_product.price,v_qty,v_line);
 end loop;
 update orders set subtotal=v_subtotal,total=v_subtotal,updated_at=now() where id=v_order_id;
 return jsonb_build_object('id',v_order_id,'public_token',v_token,'status','PENDING_PAYMENT','payment_status','PENDING','total',v_subtotal,'currency',v_business.currency);
end;$$;
grant execute on function public.create_public_order(text,text,text,text,uuid,jsonb) to anon,authenticated;

-- Payment verification is server-only; webhook code should use the service_role database connection.
grant execute on function public.mark_order_paid(uuid,text,text,numeric) to service_role;

-- Ensure payment verification cannot be applied twice.
create or replace function public.mark_order_paid(p_order_id uuid,p_provider text,p_reference text,p_amount numeric)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_order orders%rowtype;v_item order_items%rowtype;v_product products%rowtype;
begin
 select * into v_order from orders where id=p_order_id for update;if not found then raise exception 'Order not found';end if;
 if v_order.payment_status='PAID' then return jsonb_build_object('order_id',v_order.id,'status',v_order.status,'payment_status','PAID','already_processed',true);end if;
 if p_amount<>v_order.total then raise exception 'Payment amount does not match order total';end if;
 for v_item in select * from order_items where order_id=v_order.id loop
  if v_item.product_id is not null then
   select * into v_product from products where id=v_item.product_id for update;
   if v_product.track_stock and coalesce(v_product.stock_quantity,0)<v_item.quantity then raise exception 'Insufficient stock at payment confirmation';end if;
   if v_product.track_stock then update products set stock_quantity=stock_quantity-v_item.quantity,updated_at=now() where id=v_product.id;end if;
  end if;
 end loop;
 update orders set status='NEW',payment_status='PAID',updated_at=now() where id=v_order.id;
 insert into audit_logs(actor_id,business_id,action,entity_type,entity_id,metadata) values(null,v_order.business_id,'payment.verified','order',v_order.id,jsonb_build_object('provider',p_provider,'reference',p_reference,'amount',p_amount));
 insert into notifications(business_id,type,title,message,data) values(v_order.business_id,'ORDER_NEW','New paid order',concat('Order #',left(v_order.id::text,8),' has been paid and is ready for processing.'),jsonb_build_object('order_id',v_order.id));
 return jsonb_build_object('order_id',v_order.id,'status','NEW','payment_status','PAID');
end;$$;
revoke all on function public.mark_order_paid(uuid,text,text,numeric) from anon,authenticated;
grant execute on function public.mark_order_paid(uuid,text,text,numeric) to service_role;

-- ============================================================
-- Production security hardening
-- ============================================================

create or replace function public.business_role(bid uuid)
returns text
language sql
security definer
set search_path=public
stable
as $$
  select role from public.memberships
  where business_id=bid and user_id=auth.uid() and status='ACTIVE'
  limit 1;
$$;

create or replace function public.is_business_manager(bid uuid) returns boolean
language sql security definer set search_path=public stable as $$
  select exists(
    select 1 from public.memberships
    where business_id=bid and user_id=auth.uid() and status='ACTIVE'
      and role in ('OWNER','MANAGER')
  );
$$;

-- Products: staff can read operational catalogue data, but only owners/managers can mutate it.
drop policy if exists "members manage products" on public.products;
drop policy if exists "members read products" on public.products;
drop policy if exists "public read active products" on public.products;
create policy "members read products" on public.products
  for select using (public.is_business_member(business_id));
create policy "managers manage products" on public.products
  for all using (public.is_business_manager(business_id))
  with check (public.is_business_manager(business_id));

-- Locations: staff can read, owners/managers can mutate.
drop policy if exists "members manage locations" on public.locations;
drop policy if exists "members read locations" on public.locations;
drop policy if exists "public read active locations" on public.locations;
create policy "members read locations" on public.locations
  for select using (public.is_business_member(business_id));
create policy "managers manage locations" on public.locations
  for all using (public.is_business_manager(business_id))
  with check (public.is_business_manager(business_id));

-- Customers are operational records, not arbitrary writable tenant data.
drop policy if exists "members manage customers" on public.customers;
drop policy if exists "members read customers" on public.customers;
create policy "members read customers" on public.customers
  for select using (public.is_business_member(business_id));

-- Staff can read orders, but order state changes go through a controlled RPC.
drop policy if exists "members update orders" on public.orders;
drop policy if exists "members read orders" on public.orders;
create policy "members read orders" on public.orders for select using (public.is_business_member(business_id) or customer_user_id=auth.uid());

create or replace function public.update_order_status(p_order_id uuid, p_status text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_order orders%rowtype;
  v_role text;
  v_allowed boolean := false;
begin
  select * into v_order from public.orders where id=p_order_id for update;
  if not found then raise exception 'Order not found'; end if;
  v_role := public.business_role(v_order.business_id);
  if v_role is null then raise exception 'Forbidden'; end if;

  -- Staff may operate orders, but only through this state machine.
  v_allowed :=
    (v_order.status='NEW' and p_status in ('CONFIRMED','CANCELLED')) or
    (v_order.status='CONFIRMED' and p_status in ('PREPARING','CANCELLED')) or
    (v_order.status='PREPARING' and p_status in ('READY','READY_FOR_PICKUP')) or
    (v_order.status in ('READY','READY_FOR_PICKUP') and p_status='COMPLETED') or
    (v_order.status='PENDING_PAYMENT' and p_status='CANCELLED');

  if not v_allowed then raise exception 'Invalid order status transition'; end if;

  update public.orders
  set status=p_status, updated_at=now()
  where id=p_order_id;

  insert into public.audit_logs(actor_id,business_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),v_order.business_id,'order.status_updated','order',p_order_id,jsonb_build_object('from',v_order.status,'to',p_status));

  return jsonb_build_object('order_id',p_order_id,'status',p_status);
end;
$$;
revoke all on function public.update_order_status(uuid,text) from anon,authenticated;
grant execute on function public.update_order_status(uuid,text) to authenticated;

-- Only managers/owners should read sensitive audit history.
drop policy if exists "members audit" on public.audit_logs;
create policy "managers audit" on public.audit_logs
  for select using (public.is_business_manager(business_id));

-- Audit writes happen through trusted server functions, never direct client inserts.
create or replace function public.log_audit_event(
  p_business_id uuid,
  p_action text,
  p_entity_type text default null,
  p_entity_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare v_id uuid;
begin
  if not public.is_business_member(p_business_id) then raise exception 'Forbidden'; end if;
  insert into public.audit_logs(actor_id,business_id,action,entity_type,entity_id,metadata)
  values(auth.uid(),p_business_id,p_action,p_entity_type,p_entity_id,p_metadata)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.log_audit_event(uuid,text,text,uuid,jsonb) from anon,authenticated;
grant execute on function public.log_audit_event(uuid,text,text,uuid,jsonb) to authenticated;

-- Subscriptions: members can inspect, only the owner can mutate billing state.
drop policy if exists "owners manage subscription" on public.business_subscriptions;
create policy "owner manages subscription" on public.business_subscriptions
  for all using (exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=auth.uid()))
  with check (exists(select 1 from public.businesses b where b.id=business_id and b.owner_id=auth.uid()));

-- Prevent clients from writing payment records directly.
drop policy if exists "members insert payments" on public.payments;
drop policy if exists "members update payments" on public.payments;

-- Order items remain read-only to authenticated clients.
drop policy if exists "members insert order_items" on public.order_items;
drop policy if exists "members update order_items" on public.order_items;
drop policy if exists "members delete order_items" on public.order_items;

-- Payment verification remains server-only.
revoke all on function public.mark_order_paid(uuid,text,text,numeric) from anon,authenticated;
grant execute on function public.mark_order_paid(uuid,text,text,numeric) to service_role;


-- Restrict security helper functions to authenticated sessions.
revoke all on function public.business_role(uuid) from public, anon, authenticated;
grant execute on function public.business_role(uuid) to authenticated;
revoke all on function public.is_business_member(uuid) from public, anon, authenticated;
grant execute on function public.is_business_member(uuid) to authenticated;
revoke all on function public.is_business_manager(uuid) from public, anon, authenticated;
grant execute on function public.is_business_manager(uuid) to authenticated;


-- Public order tracking is capability-based. The opaque token is the only public credential.
create or replace function public.get_public_order(p_token text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_order jsonb;
begin
  if p_token is null or length(trim(p_token)) < 20 then raise exception 'Invalid tracking token'; end if;
  select jsonb_build_object(
    'id',o.id,
    'customer_name',o.customer_name,
    'total',o.total,
    'status',o.status,
    'payment_status',o.payment_status,
    'created_at',o.created_at,
    'updated_at',o.updated_at,
    'business',jsonb_build_object('name',b.name,'currency',b.currency),
    'location',case when l.id is null then null else jsonb_build_object('name',l.name,'location_type',l.location_type) end,
    'items',coalesce((select jsonb_agg(jsonb_build_object('name_snapshot',oi.name_snapshot,'quantity',oi.quantity,'unit_price',oi.unit_price,'line_total',oi.line_total) order by oi.id) from order_items oi where oi.order_id=o.id),'[]'::jsonb)
  ) into v_order
  from orders o
  join businesses b on b.id=o.business_id
  left join locations l on l.id=o.location_id
  where o.public_token=trim(p_token)
    and b.status='PUBLISHED';
  if v_order is null then raise exception 'Order not found'; end if;
  return v_order;
end;
$$;
revoke all on function public.get_public_order(text) from public, anon, authenticated;
grant execute on function public.get_public_order(text) to anon, authenticated;

-- Staff invitations. Invitation tokens are opaque and expire automatically by application policy.
create table if not exists public.staff_invites (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  email text not null,
  role text not null check(role in ('MANAGER','STAFF')),
  token_hash text not null unique,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists staff_invites_business_idx on public.staff_invites(business_id,created_at desc);
create index if not exists staff_invites_email_idx on public.staff_invites(lower(email));
alter table public.staff_invites enable row level security;
drop policy if exists "managers read staff invites" on public.staff_invites;
drop policy if exists "owners create staff invites" on public.staff_invites;
create policy "managers read staff invites" on public.staff_invites for select using (public.is_business_manager(business_id));

-- Storage metadata lives in Supabase Storage. These app-level helpers keep upload authorization centralized.
create table if not exists public.media_assets (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  path text not null unique,
  bucket text not null default 'business-media',
  mime_type text not null,
  size_bytes bigint not null check(size_bytes > 0),
  kind text not null check(kind in ('BUSINESS_LOGO','BUSINESS_COVER','PRODUCT_IMAGE','OTHER')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists media_assets_business_idx on public.media_assets(business_id,created_at desc);
alter table public.media_assets enable row level security;
drop policy if exists "members read media assets" on public.media_assets;
drop policy if exists "managers manage media assets" on public.media_assets;
create policy "members read media assets" on public.media_assets for select using (public.is_business_member(business_id));
create policy "managers manage media assets" on public.media_assets for all using (public.is_business_manager(business_id)) with check (public.is_business_manager(business_id));

-- Notification delivery queue. The DB record is authoritative; providers can be retried safely.
create table if not exists public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  channel text not null check(channel in ('EMAIL','WHATSAPP')),
  destination text not null,
  provider text,
  provider_reference text,
  status text not null default 'PENDING' check(status in ('PENDING','SENT','FAILED')),
  attempts integer not null default 0,
  last_error text,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists notification_deliveries_status_idx on public.notification_deliveries(status,created_at);
alter table public.notification_deliveries enable row level security;
drop policy if exists "members read notification deliveries" on public.notification_deliveries;
create policy "members read notification deliveries" on public.notification_deliveries for select using (exists(select 1 from public.notifications n where n.id=notification_id and public.is_business_member(n.business_id)));

-- Analytics-safe aggregate view. It exposes only tenant-scoped order totals to authenticated members.
create or replace view public.business_daily_sales with (security_invoker=true) as
select business_id,date_trunc('day',created_at)::date as sales_date,
       count(*) filter(where payment_status='PAID') as paid_orders,
       coalesce(sum(total) filter(where payment_status='PAID'),0) as gross_sales
from public.orders
group by business_id,date_trunc('day',created_at)::date;

-- Supabase Storage bucket for business/product media.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('business-media','business-media',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];

-- Public storefronts need to display uploaded media; writes remain server-controlled.
drop policy if exists "public read business media" on storage.objects;
create policy "public read business media" on storage.objects for select using (bucket_id='business-media');
