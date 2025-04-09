#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifies Docker containers are running properly for development and testing.

.DESCRIPTION
    This script checks if all required Docker containers for the authentication system
    are running correctly. It verifies the auth service, MongoDB, and MailHog containers.

.PARAMETER ContainerPrefix
    Optional prefix for container names to filter specific containers.

.PARAMETER Verbose
    Run with detailed logging.

.PARAMETER LogFile
    Optional path to the log file. Default is "docker-health-check.log" in the script directory.

.EXAMPLE
    .\docker-health-check.ps1

.EXAMPLE
    .\docker-health-check.ps1 -ContainerPrefix "auth-"

.EXAMPLE
    .\docker-health-check.ps1 -LogFile "C:\logs\docker-check.log"

.NOTES
    Author: AuthSystem Team
    Date:   April 2025
#>

param (
    [string]$ContainerPrefix = "",
    [switch]$Verbose,
    [string]$LogFile = ""
)

# Set console output encoding to UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Configure error handling and verbose output
if ($Verbose) {
    $VerbosePreference = "Continue"
    $ErrorActionPreference = "Continue"
} else {
    $VerbosePreference = "SilentlyContinue"
    $ErrorActionPreference = "Stop"
}

# Set up logging
if (-not $LogFile) {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $logDate = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $LogFile = Join-Path $scriptPath "logs\docker-health-check_$logDate.log"
}

# Create logs directory if it doesn't exist
$logDirectory = Split-Path -Parent $LogFile
if (-not (Test-Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
}

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO",
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to console with color
    Write-Host $logMessage -ForegroundColor $ForegroundColor
    
    # Write to log file
    $logMessage | Out-File -FilePath $LogFile -Append
}

# Required containers for the system to function properly
$requiredContainers = @(
    @{
        Type = "app"
        NamePatterns = @("auth-service-dev", "auth-service-test", "auth-service")
        Required = $true
        HealthEndpoint = "http://localhost:3000/health"
    },
    @{
        Type = "database"
        NamePatterns = @("mongodb-mailhog-test", "mongodb")
        Required = $true
        Port = 27017
    },
    @{
        Type = "mail"
        NamePatterns = @("mailhog-test", "mailhog")
        Required = $false # Not strictly required if using direct verification
        HealthEndpoint = "http://localhost:8025/api/v2/messages"
    }
)

function Test-TcpConnection {
    param (
        [string]$ComputerName,
        [int]$Port,
        [int]$Timeout = 1000
    )
    
    try {
        Write-Verbose "Testing TCP connection to $ComputerName on port $Port..."
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connection = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
        $wait = $connection.AsyncWaitHandle.WaitOne($Timeout, $false)
        
        if ($wait) {
            $tcpClient.EndConnect($connection)
            $tcpClient.Close()
            Write-Log "TCP connection to ${ComputerName}:${Port} successful" "INFO" Yellow
            return $true
        } else {
            $tcpClient.Close()
            Write-Log "TCP connection to ${ComputerName}:${Port} timed out" "WARNING" Yellow
            return $false
        }
    }
    catch {
        Write-Log "TCP connection error to ${ComputerName}:${Port} - $_" "ERROR" Red
        Write-Verbose "TCP connection error: $_"
        return $false
    }
}

function Test-HttpEndpoint {
    param (
        [string]$Url,
        [int]$Timeout = 5
    )
    
    try {
        Write-Verbose "Testing HTTP endpoint: $Url"
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec $Timeout -UseBasicParsing
        $statusOk = $response.StatusCode -ge 200 -and $response.StatusCode -lt 400
        
        if ($statusOk) {
            Write-Log "HTTP endpoint $Url is healthy (Status: $($response.StatusCode))" "INFO" Green
        } else {
            Write-Log "HTTP endpoint $Url returned non-success status: $($response.StatusCode)" "WARNING" Yellow
        }
        
        return $statusOk
    }
    catch {
        Write-Log "HTTP endpoint error for $Url - $_" "ERROR" Red
        Write-Verbose "HTTP endpoint error: $_"
        return $false
    }
}

function Get-ContainerList {
    param(
        [string]$Prefix = ""
    )
    
    try {
        Write-Verbose "Getting Docker container list..."
        
        if ($Prefix) {
            $filter = "--filter name=$Prefix"
            Write-Log "Filtering containers with prefix: $Prefix" "INFO" Cyan
        } else {
            $filter = ""
        }
        
        $containers = @(docker ps -a --format "{{.ID}}|{{.Names}}|{{.Status}}|{{.Ports}}" $filter)
        
        $containerList = @()
        foreach ($container in $containers) {
            $parts = $container -split "\|"
            
            if ($parts.Count -ge 3) {
                $containerInfo = @{
                    Id = $parts[0]
                    Name = $parts[1]
                    Status = $parts[2]
                    Ports = if ($parts.Count -gt 3) { $parts[3] } else { "" }
                    Running = $parts[2] -match "^Up "
                }
                
                $containerList += $containerInfo
                
                if ($containerInfo.Running) {
                    Write-Log "Container $($containerInfo.Name) is running (ID: $($containerInfo.Id))" "INFO" Green
                } else {
                    Write-Log "Container $($containerInfo.Name) is not running (ID: $($containerInfo.Id))" "WARNING" Yellow
                }
            }
        }
        
        Write-Log "Found $($containerList.Count) containers" "INFO" Cyan
        return $containerList
    }
    catch {
        $errorMsg = "Failed to get Docker container list: $_"
        Write-Log $errorMsg "ERROR" Red
        Write-Error $errorMsg
        return @()
    }
}

function Find-RequiredContainer {
    param(
        [array]$Containers,
        [string[]]$NamePatterns
    )
    
    foreach ($pattern in $NamePatterns) {
        foreach ($container in $Containers) {
            if ($container.Name -match $pattern) {
                Write-Log "Found container matching pattern '$pattern': $($container.Name)" "INFO" Green
                return $container
            }
        }
    }
    
    $patternsStr = $NamePatterns -join ", "
    Write-Log "No container found matching patterns: $patternsStr" "WARNING" Yellow
    return $null
}

function Test-DockerEnvironment {
    Write-Log "Checking Docker environment..." "INFO" Cyan
    
    # Check if Docker is installed and running
    try {
        $dockerVersion = docker version --format '{{.Server.Version}}'
        Write-Log "Docker is running - version: $dockerVersion" "SUCCESS" Green
    }
    catch {
        $errorMsg = "Docker is not running or not installed. Error: $_"
        Write-Log $errorMsg "ERROR" Red
        return @{
            Success = $false
            Message = $errorMsg
            Containers = @()
        }
    }
    
    # Get all containers
    $allContainers = Get-ContainerList -Prefix $ContainerPrefix
    Write-Verbose "Found $($allContainers.Count) containers"
    
    # Check each required container type
    $containerStatus = @()
    $allRequired = $true
    
    foreach ($requiredType in $requiredContainers) {
        $container = Find-RequiredContainer -Containers $allContainers -NamePatterns $requiredType.NamePatterns
        
        $status = @{
            Type = $requiredType.Type
            NamePatterns = $requiredType.NamePatterns
            Found = $null -ne $container
            Running = $false
            Healthy = $false
            Name = if ($container) { $container.Name } else { "Not found" }
            Required = $requiredType.Required
        }
        
        if ($container) {
            $status.Running = $container.Running
            
            # Check container health
            if ($container.Running) {
                if ($requiredType.HealthEndpoint) {
                    $status.Healthy = Test-HttpEndpoint -Url $requiredType.HealthEndpoint
                } elseif ($requiredType.Port) {
                    $status.Healthy = Test-TcpConnection -ComputerName "localhost" -Port $requiredType.Port
                } else {
                    $status.Healthy = $true # Assume healthy if no health check specified
                    Write-Log "Container $($container.Name) assumed healthy (no health check specified)" "INFO" Green
                }
            }
            
            # Log specific issues
            if (-not $status.Running) {
                Write-Log "Container $($container.Name) is not running" "WARNING" Yellow
            } elseif (-not $status.Healthy) {
                Write-Log "Container $($container.Name) is running but appears unhealthy" "WARNING" Yellow
            }
        } else {
            $patternList = $requiredType.NamePatterns -join "', '"
            $logLevel = if ($requiredType.Required) { "ERROR" } else { "WARNING" }
            $color = if ($requiredType.Required) { "Red" } else { "Yellow" }
            Write-Log "Required container of type $($requiredType.Type) not found (patterns: '$patternList')" $logLevel $color
        }
        
        $containerStatus += $status
        
        # Track if required containers are missing
        if ($requiredType.Required -and (-not $status.Found -or -not $status.Running -or -not $status.Healthy)) {
            $allRequired = $false
        }
    }
    
    # Build result object
    $result = @{
        Success = $allRequired
        Message = if ($allRequired) { "All required Docker containers are running and healthy" } else { "Some required Docker containers are missing or unhealthy" }
        Containers = $containerStatus
        AllContainers = $allContainers
    }
    
    return $result
}

# If script is being run directly (not sourced), output results
if ($MyInvocation.InvocationName -ne ".") {
    Write-Log "Starting Docker health check..." "INFO" Cyan
    Write-Log "Results will be saved to: $LogFile" "INFO" White
    
    $result = Test-DockerEnvironment
    
    if ($result.Success) {
        Write-Log "Docker environment check passed!" "SUCCESS" Green
    } else {
        Write-Log "Docker environment check failed: $($result.Message)" "ERROR" Red
    }
    
    Write-Log "Container Status Summary:" "INFO" Cyan
    foreach ($container in $result.Containers) {
        $statusColor = if ($container.Healthy) { "Green" } elseif (-not $container.Required) { "Yellow" } else { "Red" }
        $statusLevel = if ($container.Healthy) { "SUCCESS" } elseif (-not $container.Required) { "WARNING" } else { "ERROR" }
        $statusSymbol = if ($container.Healthy) { "Check" } elseif (-not $container.Required) { "!" } else { "x" }
        $statusText = if ($container.Healthy) { "Healthy" } elseif ($container.Running) { "Unhealthy" } else { "Not Running" }
        
        Write-Log "$statusSymbol $($container.Type): $($container.Name) - $statusText" $statusLevel $statusColor
    }
    
    Write-Log "Docker health check completed." "INFO" Cyan
    Write-Log "Detailed results saved to: $LogFile" "INFO" White
    
    return $result
}