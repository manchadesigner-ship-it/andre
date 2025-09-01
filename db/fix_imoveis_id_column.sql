-- Script para verificar e corrigir a estrutura da tabela imoveis
-- Verifica se a coluna 'id' existe e é a chave primária

-- Verificar se a coluna 'id' existe na tabela imoveis
DO $$
DECLARE
    column_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'imoveis'
        AND column_name = 'id'
    ) INTO column_exists;

    IF NOT column_exists THEN
        -- Se a coluna 'id' não existir, mas 'imovel_id' existir, renomear para 'id'
        IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'imoveis'
            AND column_name = 'imovel_id'
        ) THEN
            RAISE NOTICE 'Renomeando coluna imovel_id para id';
            ALTER TABLE public.imoveis RENAME COLUMN imovel_id TO id;
        ELSE
            -- Se nenhuma das colunas existir, criar a coluna 'id'
            RAISE NOTICE 'Criando coluna id';
            ALTER TABLE public.imoveis ADD COLUMN id BIGINT;
            
            -- Gerar valores sequenciais para a coluna id
            CREATE SEQUENCE IF NOT EXISTS imoveis_id_seq;
            ALTER TABLE public.imoveis ALTER COLUMN id SET DEFAULT nextval('imoveis_id_seq');
            UPDATE public.imoveis SET id = nextval('imoveis_id_seq') WHERE id IS NULL;
        END IF;
    END IF;

    -- Verificar se a coluna 'id' é a chave primária
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
        WHERE tc.constraint_type = 'PRIMARY KEY'
        AND tc.table_schema = 'public'
        AND tc.table_name = 'imoveis'
        AND kcu.column_name = 'id'
    ) THEN
        -- Remover qualquer chave primária existente
        EXECUTE (
            SELECT 'ALTER TABLE public.imoveis DROP CONSTRAINT ' || constraint_name
            FROM information_schema.table_constraints
            WHERE table_schema = 'public'
            AND table_name = 'imoveis'
            AND constraint_type = 'PRIMARY KEY'
            LIMIT 1
        );
        
        -- Adicionar chave primária na coluna 'id'
        RAISE NOTICE 'Adicionando chave primária na coluna id';
        ALTER TABLE public.imoveis ADD PRIMARY KEY (id);
    END IF;

    -- Garantir que a coluna 'id' não aceita valores nulos
    ALTER TABLE public.imoveis ALTER COLUMN id SET NOT NULL;
    
    -- Atualizar as políticas de segurança para usar a coluna 'id'
    DROP POLICY IF EXISTS imoveis_select ON public.imoveis;
    CREATE POLICY imoveis_select ON public.imoveis
      FOR SELECT USING (deleted_at IS NULL AND auth.uid() = user_ref);
    
    DROP POLICY IF EXISTS imoveis_update ON public.imoveis;
    CREATE POLICY imoveis_update ON public.imoveis
      FOR UPDATE USING (deleted_at IS NULL AND auth.uid() = user_ref)
      WITH CHECK (auth.uid() = user_ref);

END $$;

-- Adicionar função para obter informações da tabela
CREATE OR REPLACE FUNCTION get_table_info(table_name TEXT)
RETURNS TABLE (
    column_name TEXT,
    data_type TEXT,
    is_primary_key BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.column_name::TEXT,
        c.data_type::TEXT,
        CASE WHEN pk.column_name IS NOT NULL THEN TRUE ELSE FALSE END AS is_primary_key
    FROM 
        information_schema.columns c
    LEFT JOIN (
        SELECT kcu.column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
        WHERE tc.constraint_type = 'PRIMARY KEY'
        AND tc.table_schema = 'public'
        AND tc.table_name = table_name
    ) pk ON c.column_name = pk.column_name
    WHERE 
        c.table_schema = 'public'
        AND c.table_name = table_name
    ORDER BY 
        c.ordinal_position;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Comentário para documentação
COMMENT ON FUNCTION get_table_info(TEXT) IS 'Retorna informações sobre as colunas de uma tabela, incluindo nome, tipo de dados e se é chave primária';