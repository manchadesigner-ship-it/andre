$supabaseUrl = "https://cnmdhsjmmbibkywuvatm.supabase.co"
$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNubWRoc2ptbWJpYmt5d3V2YXRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU5MTA0MjUsImV4cCI6MjA3MTQ4NjQyNX0.pVZJrf5Hv24yUHEfroURqugIhSNbh21GfczW00Y2SFk"

Write-Host "Verificando estrutura da tabela imoveis..."

try {
    $headers = @{
        'apikey' = $anonKey
        'Authorization' = "Bearer $anonKey"
        'Content-Type' = 'application/json'
    }

    # Testar se a coluna share_links existe
    Write-Host "`n1. Testando coluna share_links:"
    try {
        $response = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/imoveis?select=share_links&limit=1" -Headers $headers -Method Get
        Write-Host "✅ Coluna share_links existe e é acessível"
        Write-Host "Conteúdo: $response"
    } catch {
        Write-Host "❌ Coluna share_links não existe ou não é acessível"
        Write-Host "Erro: $($_.Exception.Message)"
    }

    # Testar se a coluna plantas existe
    Write-Host "`n2. Testando coluna plantas:"
    try {
        $response = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/imoveis?select=plantas&limit=1" -Headers $headers -Method Get
        Write-Host "✅ Coluna plantas existe e é acessível"
        Write-Host "Conteúdo: $response"
    } catch {
        Write-Host "❌ Coluna plantas não existe ou não é acessível"
        Write-Host "Erro: $($_.Exception.Message)"
    }

    # Verificar campos disponíveis
    Write-Host "`n3. Verificando campos disponíveis:"
    try {
        $response = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/imoveis?limit=1" -Headers $headers -Method Get
        if ($response -and $response.Count -gt 0) {
            Write-Host "Campos encontrados na tabela:"
            $response[0].PSObject.Properties | ForEach-Object {
                Write-Host "  - $($_.Name): $($_.Value)"
            }
        }
    } catch {
        Write-Host "❌ Erro ao consultar campos: $($_.Exception.Message)"
    }

} catch {
    Write-Host "❌ Erro geral: $($_.Exception.Message)"
}
