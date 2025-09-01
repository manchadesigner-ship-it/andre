# Script PowerShell para executar o script SQL que corrige a estrutura da tabela imoveis

# Carregar as credenciais do Supabase
$supabaseInfoPath = "$PSScriptRoot\..\supabase-info"
$supabaseUrl = Get-Content "$supabaseInfoPath\url.txt" -Raw
$supabaseKey = Get-Content "$supabaseInfoPath\service_key.txt" -Raw

# Remover espaços em branco e quebras de linha
$supabaseUrl = $supabaseUrl.Trim()
$supabaseKey = $supabaseKey.Trim()

Write-Host "Executando script SQL para corrigir a estrutura da tabela imoveis..."

# Ler o conteúdo do script SQL
$sqlScript = Get-Content "$PSScriptRoot\fix_imoveis_id_column.sql" -Raw

# Preparar os headers para a requisição
$headers = @{
    "apikey" = $supabaseKey
    "Authorization" = "Bearer $supabaseKey"
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}

# Preparar o corpo da requisição
$body = @{
    "query" = $sqlScript
} | ConvertTo-Json

# Executar a requisição para o endpoint SQL do Supabase
try {
    $response = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/exec_sql" -Method POST -Headers $headers -Body $body
    Write-Host "Script SQL executado com sucesso!"
    Write-Host $response
} catch {
    Write-Host "Erro ao executar o script SQL: $_"
    
    # Se o endpoint exec_sql não estiver disponível, informar ao usuário
    Write-Host "\nO endpoint exec_sql pode não estar disponível no seu projeto Supabase."
    Write-Host "Você pode executar o script manualmente no SQL Editor do Supabase Studio:"
    Write-Host "1. Acesse o Supabase Studio do seu projeto"
    Write-Host "2. Vá para a seção SQL Editor"
    Write-Host "3. Cole o conteúdo do arquivo fix_imoveis_id_column.sql"
    Write-Host "4. Execute o script"
}