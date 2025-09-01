# Script para verificar estrutura do banco de dados
$supabaseUrl = "https://cnmdhsjmmbibkywuvatm.supabase.co"
$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNubWRoc2ptbWJpYmt5d3V2YXRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU5MTA0MjUsImV4cCI6MjA3MTQ4NjQyNX0.pVZJrf5Hv24yUHEfroURqugIhSNbh21GfczW00Y2SFk"

Write-Host "Verificando estrutura da tabela imoveis..."

try {
    # Fazer uma consulta simples para ver a estrutura
    $headers = @{
        'apikey' = $anonKey
        'Authorization' = "Bearer $anonKey"
        'Content-Type' = 'application/json'
    }
    
    # Tentar buscar um registro para ver quais campos existem
    $response = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/imoveis?limit=1" -Headers $headers -Method Get
    
    if ($response -and $response.Count -gt 0) {
        Write-Host "✅ Campos encontrados na tabela imoveis:"
        $response[0].PSObject.Properties | ForEach-Object {
            Write-Host "  - $($_.Name): $($_.Value)"
        }
    } else {
        Write-Host "❌ Nenhum registro encontrado na tabela imoveis"
    }
} catch {
    Write-Host "❌ Erro ao acessar a tabela: $($_.Exception.Message)"
}

Write-Host "`nTestando acesso com diferentes campos ID..."

# Testar acesso com id
try {
    $response = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/imoveis?select=id&limit=1" -Headers $headers -Method Get
    Write-Host "✅ Campo 'id' existe e é acessível"
} catch {
    Write-Host "❌ Campo 'id' não existe ou não é acessível: $($_.Exception.Message)"
}

# Testar acesso com imovel_id
try {
    $response = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/imoveis?select=imovel_id&limit=1" -Headers $headers -Method Get
    Write-Host "✅ Campo 'imovel_id' existe e é acessível"
} catch {
    Write-Host "❌ Campo 'imovel_id' não existe ou não é acessível: $($_.Exception.Message)"
}

# Testar acesso com share_links
try {
    $response = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/imoveis?select=share_links&limit=1" -Headers $headers -Method Get
    Write-Host "✅ Campo 'share_links' existe e é acessível"
} catch {
    Write-Host "❌ Campo 'share_links' não existe ou não é acessível: $($_.Exception.Message)"
}

Write-Host "`nScript concluído!"
