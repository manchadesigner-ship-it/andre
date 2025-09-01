# Script para adicionar coluna share_links na tabela imoveis
param(
    [string]$SupabaseUrl = "https://cnmdhsjmmbibkywuvatm.supabase.co",
    [string]$ServiceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNubWRoc2ptbWJpYmt5d3V2YXRtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTkxMDQyNSwiZXhwIjoyMDcxNDg2NDI1fQ.ER4FTSZD0YR6fV9OWUSr9iRi9DWCW6odQewFncvcaIc"
)

Write-Host "Executando adição da coluna share_links no Supabase..." -ForegroundColor Green

# Ler o conteúdo do arquivo SQL
$sqlContent = Get-Content -Path "db/add_share_links_column.sql" -Raw -Encoding UTF8

# Preparar o corpo da requisição
$body = @{
    query = $sqlContent
} | ConvertTo-Json

# Fazer a requisição para o Supabase
try {
    $response = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/rpc/exec_sql" -Method POST -Headers @{
        "Authorization" = "Bearer $ServiceRoleKey"
        "Content-Type" = "application/json"
        "apikey" = $ServiceRoleKey
    } -Body $body

    Write-Host "✅ Coluna share_links adicionada com sucesso!" -ForegroundColor Green
    Write-Host "Resposta: $($response | ConvertTo-Json)" -ForegroundColor Yellow
} catch {
    Write-Host "❌ Erro ao executar SQL: $($_.Exception.Message)" -ForegroundColor Red
    
    # Tentar método alternativo usando SQL direto
    Write-Host "Tentando método alternativo..." -ForegroundColor Yellow
    
    $simpleSql = @"
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
"@

    $body2 = @{
        query = $simpleSql
    } | ConvertTo-Json

    try {
        $response2 = Invoke-RestMethod -Uri "$SupabaseUrl/rest/v1/rpc/exec_sql" -Method POST -Headers @{
            "Authorization" = "Bearer $ServiceRoleKey"
            "Content-Type" = "application/json"
            "apikey" = $ServiceRoleKey
        } -Body $body2

        Write-Host "✅ Coluna share_links adicionada com sucesso (método alternativo)!" -ForegroundColor Green
    } catch {
        Write-Host "❌ Erro no método alternativo: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Você pode executar o SQL manualmente no painel do Supabase:" -ForegroundColor Yellow
        Write-Host $simpleSql -ForegroundColor Cyan
    }
}

Write-Host "Script concluído!" -ForegroundColor Green
