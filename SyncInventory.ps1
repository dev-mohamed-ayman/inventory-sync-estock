# Pharmacy Inventory Sync Agent
# Created for: Max Pharmacy
# Version: 1.0.0

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ConfigFile = Join-Path $PSScriptRoot "config.json"
$LogFile = Join-Path $PSScriptRoot "logs\sync.log"

# --- Logging Functions ---
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
    $LogEntry | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

function Clear-Log {
    if (Test-Path $LogFile) {
        Remove-Item $LogFile -Force
    }
    # Create directory if not exists
    $LogDir = Split-Path $LogFile -Parent
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force
    }
}

# --- Initialization ---
try {
    Clear-Log
    Write-Log "Starting Pharmacy Inventory Sync Agent..."
    $StartTime = Get-Date

    if (-not (Test-Path $ConfigFile)) {
        throw "Configuration file not found: $ConfigFile"
    }

    $Config = Get-Content $ConfigFile | ConvertFrom-Json
    Write-Log "Configuration loaded successfully."

    if ($Config.password -eq "your_password") {
        Write-Log "WARNING: You are using the default password in config.json. Please update it." -Level "WARNING"
    }

    # --- SQL Connection ---
    Write-Log "Connecting to SQL Server: $($Config.sqlServer)..."
    
    if ([string]::IsNullOrWhiteSpace($Config.username)) {
        Write-Log "Using Windows Authentication (Integrated Security)."
        $ConnectionString = "Server=$($Config.sqlServer);Database=$($Config.database);Integrated Security=True;Connect Timeout=30;"
    } else {
        Write-Log "Using SQL Server Authentication (User: $($Config.username))."
        $ConnectionString = "Server=$($Config.sqlServer);Database=$($Config.database);User ID=$($Config.username);Password=$($Config.password);Connect Timeout=30;"
    }
    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    
    try {
        $Connection.Open()
        Write-Log "SQL Connection Status: SUCCESS"
    } catch {
        Write-Log "SQL Connection Status: FAILED" -Level "ERROR"
        throw "Failed to connect to SQL Server: $($_.Exception.Message)"
    }

    # --- Data Retrieval ---
    Write-Log "Loading products and calculating stock..."
    
    $SqlQuery = @"
SELECT 
    p.product_id,
    p.product_code AS code,
    COALESCE(p.product_name_en, p.product_name_ar) AS name,
    CAST(p.sell_price AS FLOAT) AS price,
    ISNULL(SUM(CAST(pa.amount AS FLOAT)), 0) AS quantity,
    p.product_int_code AS international_barcode,
    '' AS image
FROM Products p
LEFT JOIN Product_Amount pa ON p.product_id = pa.product_id
GROUP BY p.product_id, p.product_code, p.product_name_en, p.product_name_ar, p.sell_price, p.product_int_code
"@

    $Command = $Connection.CreateCommand()
    $Command.CommandText = $SqlQuery
    $Adapter = New-Object System.Data.SqlClient.SqlDataAdapter($Command)
    $DataTable = New-Object System.Data.DataTable
    [void]$Adapter.Fill($DataTable)
    
    $ProductsCount = $DataTable.Rows.Count
    Write-Log "Number Of Products Loaded: $ProductsCount"

    if ($ProductsCount -eq 0) {
        Write-Log "No products found to sync."
    } else {
        # --- API Sync ---
        Write-Log "Preparing data for API..."
        
        $ProductsList = New-Object System.Collections.Generic.List[Object]
        foreach ($Row in $DataTable.Rows) {
            $ProductCode = if ($Row.code -ne [DBNull]::Value) { $Row.code.ToString().Trim() } else { "" }
            $ProductName = if ($Row.name -ne [DBNull]::Value) { $Row.name.ToString().Trim() } else { "" }
            
            # API requires a name. Fallback to code if name is missing.
            if ([string]::IsNullOrWhiteSpace($ProductName)) {
                $ProductName = "Product " + $ProductCode
            }

            # Skip product if it has no code (API usually requires a unique identifier)
            if ([string]::IsNullOrWhiteSpace($ProductCode)) {
                Write-Log "Skipping product without code (ID: $($Row.product_id))" -Level "WARNING"
                continue
            }

            $Product = @{
                code = $ProductCode
                name = $ProductName
                price = [double]$Row.price
                quantity = [double]$Row.quantity
                international_barcode = if ($Row.international_barcode -ne [DBNull]::Value) { $Row.international_barcode.ToString().Trim() } else { "" }
                image = if ($Row.image -ne [DBNull]::Value) { $Row.image.ToString().Trim() } else { "" }
            }
            $ProductsList.Add($Product)
        }

        Write-Log "Number Of Products After Filtering: $($ProductsList.Count)"
        Write-Log "Preparing JSON payload..."

        $PayloadObject = @{
            products = $ProductsList
        }
        $Payload = $PayloadObject | ConvertTo-Json -Depth 10
        
        Write-Log "Payload size: $($Payload.Length) characters"
        Write-Log "First 500 chars of payload: $($Payload.Substring(0, [Math]::Min(500, $Payload.Length)))"

        Write-Log "Sending data to API: $($Config.apiUrl)..."
        
        $Headers = @{
            "X-API-KEY" = $Config.apiKey
            "Content-Type" = "application/json"
        }

        try {
            $BodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Payload)
            $Response = Invoke-RestMethod -Uri $Config.apiUrl -Method Post -Headers $Headers -Body $BodyBytes -TimeoutSec $Config.requestTimeoutSeconds
            
            Write-Log "Number Of Products Sent: $($ProductsList.Count)"
            Write-Log "HTTP Status Code: 200 (Assumed SUCCESS)"
            Write-Log "API Response: $($Response | ConvertTo-Json -Compress)"
        } catch {
            $StatusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
            Write-Log "HTTP Status Code: $StatusCode" -Level "ERROR"
            Write-Log "API Error: $($_.Exception.Message)" -Level "ERROR"
            
            if ($_.Exception.Response) {
                $Reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $ErrorResponse = $Reader.ReadToEnd()
                Write-Log "API Error Response: $ErrorResponse" -Level "ERROR"
            }
            throw $_
        }
    }

    $Connection.Close()
    
    $EndTime = Get-Date
    $Duration = $EndTime - $StartTime
    Write-Log "End Time: $($EndTime.ToString("yyyy-MM-dd HH:mm:ss"))"
    Write-Log "Duration: $($Duration.TotalSeconds) seconds"
    Write-Log "Sync completed successfully."

} catch {
    Write-Log "CRITICAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Full Exception Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    
    Write-Host "`n--------------------------------------------------" -ForegroundColor Red
    Write-Host "ERROR DETECTED!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host "--------------------------------------------------`n" -ForegroundColor Red
    
    Read-Host "Press Enter To Exit"
    exit 1
} finally {
    if ($Connection -and $Connection.State -eq "Open") {
        $Connection.Close()
    }
}
