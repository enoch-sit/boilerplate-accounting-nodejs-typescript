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

.EXAMPLE
    .\docker-health-check.ps1

.EXAMPLE
    .\docker-health-check.ps1 -ContainerPrefix "auth-"

.NOTES
    Author: AuthSystem Team
    Date:   April 2025
#>

param (
    [string]$ContainerPrefix = "",
    [switch]$Verbose
)

# Configure error handling and verbose output
if ($Verbose) {
    $VerbosePreference = "Continue"
    $ErrorActionPreference = "Continue"
} else {
    $VerbosePreference = "SilentlyContinue"
    $ErrorActionPreference = "Stop"
}

# Required containers for the system to function properly
$requiredContainers = @(
    @{
        Type = "app"
        NamePatterns = @("auth-service", "auth-service-dev", "auth-service-mailhog-test")
        Required = $true
        HealthEndpoint = "http://localhost:3000/api/health"
    },
    @{
        Type = "database"
        NamePatterns = @("mongodb", "mongodb-mailhog-test")
        Required = $true
        Port = 27017
    },
    @{
        Type = "mail"
        NamePatterns = @("mailhog", "mailhog-test")
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
            return $true
        } else {
            $tcpClient.Close()
            return $false
        }
    }
    catch {
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
        return ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400)
    }
    catch {
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
            }
        }
        
        return $containerList
    }
    catch {
        Write-Error "Failed to get Docker container list: $_"
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
                return $container
            }
        }
    }
    
    return $null
}

function Test-DockerEnvironment {
    Write-Host "Checking Docker environment..." -ForegroundColor Cyan
    
    # Check if Docker is installed and running
    try {
        $dockerVersion = docker version --format '{{.Server.Version}}'
        Write-Host "Docker version: $dockerVersion" -ForegroundColor Green
    }
    catch {
        return @{
            Success = $false
            Message = "Docker is not running or not installed. Error: $_"
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
                }
            }
            
            # Log specific issues
            if (-not $status.Running) {
                Write-Host "Container $($container.Name) is not running" -ForegroundColor Yellow
            } elseif (-not $status.Healthy) {
                Write-Host "Container $($container.Name) is running but appears unhealthy" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Required container of type $($requiredType.Type) not found (patterns: $($requiredType.NamePatterns -join ', '))" -ForegroundColor Yellow
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
    $result = Test-DockerEnvironment
    
    if ($result.Success) {
        Write-Host "`n✅ Docker environment check passed" -ForegroundColor Green
    } else {
        Write-Host "`n❌ Docker environment check failed: $($result.Message)" -ForegroundColor Red
    }
    
    Write-Host "`nContainer Status:" -ForegroundColor Cyan
    foreach ($container in $result.Containers) {
        $statusColor = if ($container.Healthy) { "Green" } elseif (-not $container.Required) { "Yellow" } else { "Red" }
        $statusSymbol = if ($container.Healthy) { "✅" } elseif (-not $container.Required) { "⚠️" } else { "❌" }
        
        Write-Host "$statusSymbol $($container.Type): $($container.Name) - " -NoNewline
        Write-Host $(if ($container.Healthy) { "Healthy" } elseif ($container.Running) { "Unhealthy" } else { "Not Running" }) -ForegroundColor $statusColor
    }
    
    return $result
}