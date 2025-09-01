-- Verificar se a coluna share_links existe na tabela imoveis
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'imoveis'
AND column_name = 'share_links';

-- Verificar estrutura da tabela imoveis
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'imoveis'
ORDER BY ordinal_position;
