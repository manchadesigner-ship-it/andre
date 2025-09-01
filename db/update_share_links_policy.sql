-- Atualizar políticas de segurança para permitir acesso à coluna share_links

-- Atualizar política de seleção para incluir explicitamente a coluna share_links
DROP POLICY IF EXISTS imoveis_select ON public.imoveis;
CREATE POLICY imoveis_select ON public.imoveis
  FOR SELECT USING (deleted_at IS NULL AND auth.uid() = user_ref);

-- Atualizar política de atualização para permitir modificar a coluna share_links
DROP POLICY IF EXISTS imoveis_update ON public.imoveis;
CREATE POLICY imoveis_update ON public.imoveis
  FOR UPDATE USING (deleted_at IS NULL AND auth.uid() = user_ref)
  WITH CHECK (auth.uid() = user_ref);

-- Garantir que a coluna share_links tenha um valor padrão adequado
ALTER TABLE public.imoveis
  ALTER COLUMN share_links SET DEFAULT '{}'::text[];

-- Comentário para documentação
COMMENT ON COLUMN public.imoveis.share_links IS 'Array de links de compartilhamento gerados para o imóvel';