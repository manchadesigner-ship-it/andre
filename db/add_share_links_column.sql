-- Adicionar coluna share_links na tabela de imóveis
-- Verifica se a coluna já existe antes de adicionar
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'imoveis' 
        AND column_name = 'share_links'
    ) THEN
        ALTER TABLE public.imoveis ADD COLUMN share_links text[] DEFAULT '{}'::text[];
        RAISE NOTICE 'Coluna share_links adicionada com sucesso';
    ELSE
        RAISE NOTICE 'Coluna share_links já existe';
    END IF;
END $$;

-- Adicionar índice para melhorar performance de consultas
CREATE INDEX IF NOT EXISTS imoveis_share_links_idx ON public.imoveis USING GIN (share_links);

-- Comentário para documentação
COMMENT ON COLUMN public.imoveis.share_links IS 'Array de links de compartilhamento gerados para o imóvel';

-- Atualizar políticas de segurança para permitir acesso à coluna share_links
-- Política de seleção
DROP POLICY IF EXISTS imoveis_select ON public.imoveis;
CREATE POLICY imoveis_select ON public.imoveis
  FOR SELECT USING (auth.uid() = user_ref);

-- Política de atualização
DROP POLICY IF EXISTS imoveis_update ON public.imoveis;
CREATE POLICY imoveis_update ON public.imoveis
  FOR UPDATE USING (auth.uid() = user_ref)
  WITH CHECK (auth.uid() = user_ref);

-- Garantir que a coluna share_links tenha um valor padrão adequado
ALTER TABLE public.imoveis
  ALTER COLUMN share_links SET DEFAULT '{}'::text[];