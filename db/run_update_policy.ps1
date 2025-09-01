# Script para executar o SQL de atualização de políticas no Supabase

# Definir variáveis do Supabase
$SUPABASE_URL = "https://cnmdhsjmmbibkywuvatm.supabase.co"
$SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNubWRoc2ptbWJpYmt5d3V2YXRtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTkxMDQyNSwiZXhwIjoyMDcxNDg2NDI1fQ.ER4FTSZD0YR6fV9OWUSr9iRi9DWCW6odQewFncvcaIc"

# Ler o conteúdo do arquivo SQL
$SQL_CONTENT = Get-Content -Path "$PSScriptRoot\update_share_links_policy.sql" -Raw

# Executar o SQL usando curl
Write-Host "Executando atualização de políticas no Supabase..."

$headers = @{
    "apikey" = $SUPABASE_SERVICE_KEY
    "Authorization" = "Bearer $SUPABASE_SERVICE_KEY"
    "Content-Type" = "application/json"
    "Prefer" = "return=minimal"
}

$body = @{
    "query" = $SQL_CONTENT
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/rpc/exec_sql" -Method POST -Headers $headers -Body $body
    Write-Host "Políticas atualizadas com sucesso!"
} catch {
    Write-Host "Erro ao executar SQL: $_"
    Write-Host $_.Exception.Response.StatusCode.value__
    Write-Host $_.Exception.Response.StatusDescription
}