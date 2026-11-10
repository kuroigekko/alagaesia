-- Rode este arquivo inteiro no Supabase: SQL Editor > New query > Run

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text, nome text,
  papel text not null default 'jogador' check (papel in ('mestre','jogador')),
  liberado boolean not null default false,
  criado_em timestamptz not null default now()
);
create table if not exists public.missoes (
  id bigint generated always as identity primary key,
  titulo text not null, descricao text, recompensa text,
  status text not null default 'ativa' check (status in ('ativa','concluida','falhou')),
  criado_em timestamptz not null default now()
);
create table if not exists public.sessoes (
  id bigint generated always as identity primary key,
  numero int, titulo text not null, data date, resumo text,
  publicada boolean not null default false,
  criado_em timestamptz not null default now()
);

create or replace function public.is_mestre() returns boolean
language sql security definer set search_path = public stable as
$$ select exists(select 1 from profiles where id = auth.uid() and papel = 'mestre' and liberado) $$;
create or replace function public.is_liberado() returns boolean
language sql security definer set search_path = public stable as
$$ select exists(select 1 from profiles where id = auth.uid() and liberado) $$;

create or replace function public.novo_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, email, nome)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', new.email));
  return new;
end $$;
drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario after insert on auth.users
  for each row execute function public.novo_usuario();

alter table public.profiles enable row level security;
alter table public.missoes  enable row level security;
alter table public.sessoes  enable row level security;

create policy "perfil: ver o proprio ou todos se mestre" on public.profiles
  for select using (id = auth.uid() or public.is_mestre());
create policy "perfil: mestre altera" on public.profiles
  for update using (public.is_mestre()) with check (public.is_mestre());

create policy "missoes: liberados leem" on public.missoes
  for select using (public.is_liberado());
create policy "missoes: mestre escreve" on public.missoes
  for all using (public.is_mestre()) with check (public.is_mestre());

create policy "sessoes: jogadores leem as publicadas" on public.sessoes
  for select using (public.is_mestre() or (public.is_liberado() and publicada));
create policy "sessoes: mestre escreve" on public.sessoes
  for all using (public.is_mestre()) with check (public.is_mestre());
