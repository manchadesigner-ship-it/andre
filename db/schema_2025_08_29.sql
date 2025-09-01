-- Schema setup for Imóveis App - 2025-08-29
-- Safe to run multiple times (IF NOT EXISTS / additive changes)

-- ===== Extensions =====
create extension if not exists pg_trgm;

-- ===== Enums =====
-- Status do imóvel
do $$
begin
  if not exists (select 1 from pg_type where typname = 'imovel_status') then
    create type imovel_status as enum ('disponivel','alugado','manutencao');
  end if;
end$$;

-- (Opcional) Tipos usados em despesas/contratos se desejar enums
-- create type despesa_tipo as enum ('condominio','iptu','manutencao','outro','taxa_extra','taxa_lixo');
-- create type contrato_tipo as enum ('residencial','comercial');
-- create type contrato_reajuste as enum ('anual','bienal','nenhum');
-- create type contrato_status as enum ('ativo','inativo','encerrado');

-- ===== Funções utilitárias =====
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- ===== Tabelas existentes (aprimoradas) =====
-- Usuários e Clientes já existem conforme seu arquivo; sem alterações aqui

-- ===== Imóveis =====
-- A tabela já existe (bigint PK). Adiciona campos que o app usa, se faltarem.
alter table public.imoveis
  add column if not exists nome text,
  add column if not exists numero_iptu text,
  add column if not exists uc_energia text,
  add column if not exists uc_agua text,
  add column if not exists internet numeric,
  add column if not exists area numeric,
  add column if not exists descricao text,
  add column if not exists mobiliado boolean not null default false,
  add column if not exists pets boolean not null default false,
  add column if not exists observacoes text,
  add column if not exists senha_alarme text,
  add column if not exists senha_internet text,
  add column if not exists deleted_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

-- Arrays com default
alter table public.imoveis
  alter column fotos_divulgacao set default '{}'::text[],
  alter column fotos_manutencao set default '{}'::text[],
  alter column plantas set default '{}'::text[];

-- Índices
create index if not exists imoveis_status_idx on public.imoveis(status);
create index if not exists imoveis_deleted_at_idx on public.imoveis(deleted_at);
create index if not exists imoveis_endereco_trgm_idx on public.imoveis using gin (endereco gin_trgm_ops);

-- Trigger updated_at
do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'imoveis_set_updated_at') then
    create trigger imoveis_set_updated_at
    before update on public.imoveis
    for each row execute function set_updated_at();
  end if;
end$$;

-- RLS
alter table public.imoveis enable row level security;

drop policy if exists imoveis_select on public.imoveis;
create policy imoveis_select on public.imoveis
for select using (deleted_at is null and auth.uid() = user_ref);

drop policy if exists imoveis_insert on public.imoveis;
create policy imoveis_insert on public.imoveis
for insert with check (auth.uid() = user_ref);

drop policy if exists imoveis_update on public.imoveis;
create policy imoveis_update on public.imoveis
for update using (deleted_at is null and auth.uid() = user_ref)
with check (auth.uid() = user_ref);

-- ===== Despesas (opcional, caso precise alinhar) =====
-- Garante colunas de auditoria e RLS por user_ref
alter table public.despesas
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists deleted_at timestamptz,
  add column if not exists user_ref uuid;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'despesas_set_updated_at') then
    create trigger despesas_set_updated_at
    before update on public.despesas
    for each row execute function set_updated_at();
  end if;
end$$;

alter table public.despesas enable row level security;

drop policy if exists despesas_select on public.despesas;
create policy despesas_select on public.despesas
for select using (deleted_at is null and auth.uid() = user_ref);

drop policy if exists despesas_insert on public.despesas;
create policy despesas_insert on public.despesas
for insert with check (auth.uid() = user_ref);

drop policy if exists despesas_update on public.despesas;
create policy despesas_update on public.despesas
for update using (deleted_at is null and auth.uid() = user_ref)
with check (auth.uid() = user_ref);

-- ===== Storage (compartilhamento) =====
-- Garanta o bucket "galeria" público via painel. Policy de leitura pública (opcional):
create policy if not exists public_read_galeria on storage.objects
for select using (bucket_id = 'galeria');

-- Fim do script
