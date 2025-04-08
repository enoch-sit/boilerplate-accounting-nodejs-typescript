#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Checks the health of Docker containers required for the testing environment.

.DESCRIPTION
    This script verifies that Docker Desktop is running and all required containers
    for the authentication system testing are up and healthy.

.EXAMPLE
    . .\docker-health-check.ps1
    $status = Test-DockerEnvironment
    if ($status.Success) { Write-Host "Docker environment is healthy" }

.NOTES
    Author: AuthSystem Team
    Date:   April 2025
#>

# Function to check if Docker Desktop is running
function Test-DockerDesktopRunning {
    try {
        $dockerProcess = Get-Process 'com.docker.backend' -ErrorAction SilentlyContinue
        if ($null -eq $dockerProcess) {
            return $false
        }
        
        # Also verify docker CLI is responding
        $dockerInfoOutput = docker info 2>&1
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
}

# Function to check if a container is running by container name
function Test-ContainerRunning {
    param (
        [string]$ContainerName
    )
    
    try {
        $containerInfo = docker ps --filter "name=$ContainerName" --format "{{.Names}}" 2>&1
        return ($containerInfo -eq $ContainerName)
    }
    catch {
        return $false
    }
}

# Function to check if a container's health status is healthy
function Test-ContainerHealth {
    param (
        [string]$ContainerName
    )
    
    try {
        $healthStatus = docker inspect --format "{{.State.Health.Status}}" $ContainerName 2>&1
        if ($LASTEXITCODE -ne 0) {
            # Container doesn't have health check defined
            return $true
        }
        
        return ($healthStatus -eq "healthy")
    }
    catch {
        # If we can't get health, assume it's ok if it's running
        return $true
    }
}

# Function to start a container if it's not running
function Start-Container {
    param (
        [string]$ContainerName,
        [string]$ComposeFile
    )
    
    try {
        if (-not (Test-ContainerRunning -ContainerName $ContainerName)) {
            Write-Host "Starting container $ContainerName..." -ForegroundColor Yellow
            
            if ($ComposeFile) {
                # Start using docker-compose
                docker-compose -f $ComposeFile up -d $ContainerName 2>&1 | Out-Null
            } else {
                # Start using docker
                docker start $ContainerName 2>&1 | Out-Null
            }
            
            # Wait a moment for container to initialize
            Start-Sleep -Seconds 3
            
            return (Test-ContainerRunning -ContainerName $ContainerName)
        }
        
        return $true
    }
    catch {
        return $false
    }
}

# Function to check if a port is open on localhost
function Test-PortOpen {
    param (
        [int]$Port
    )
    
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connection = $tcp.BeginConnect('localhost', $Port, $null, $null)
        $wait = $connection.AsyncWaitHandle.WaitOne(1000, $false)
        
        if ($wait) {
            $tcp.EndConnect($connection)
            $tcp.Close()
            return $true
        } else {
            $tcp.Close()
            return $false
        }
    }
    catch {
        return $false
    }
}

# Main function to test Docker environment health
function Test-DockerEnvironment {
    # Define the required containers and their ports
    $requiredContainers = @(
        @{
            Name = "mongodb"
            Port = 27017
            ComposeFile = "docker-compose.dev.yml"
        },
        @{
            Name = "mailhog"
            Port = 8025
            ComposeFile = "docker-compose.dev.yml"
        },
        @{
            Name = "auth-service"
            Port = 3000
            ComposeFile = "docker-compose.dev.yml"
        }
    )
    
    # First check if Docker Desktop is running
    if (-not (Test-DockerDesktopRunning)) {
        return @{
            Success = $false
            Message = "Docker Desktop is not running"
            Containers = @()
        }
    }
    
    # Check each required container
    $containerStatuses = @()
    $overallSuccess = $true
    
    foreach ($container in $requiredContainers) {
        $isRunning = Test-ContainerRunning -ContainerName $container.Name
        
        # Try to start container if it's not running
        if (-not $isRunning) {
            $isRunning = Start-Container -ContainerName $container.Name -ComposeFile $container.ComposeFile
        }
        
        # Check health only if container is running
        $isHealthy = $isRunning -and (Test-ContainerHealth -ContainerName $container.Name)
        
        # Check port only if container is running and healthy
        $portOpen = $isRunning -and $isHealthy -and (Test-PortOpen -Port $container.Port)
        
        $containerStatuses += @{
            Name = $container.Name
            Running = $isRunning
            Healthy = $isHealthy
            PortOpen = $portOpen
        }
        
        # Update overall success
        if (-not ($isRunning -and $isHealthy -and $portOpen)) {
            $overallSuccess = $false
        }
    }
    
    # Return the result
    return @{
        Success = $overallSuccess
        Containers = $containerStatuses
        Message = if (-not $overallSuccess) { "Not all required containers are running and healthy" } else { "Docker environment is healthy" }
    }
}

# If script is run directly (not sourced), run the test
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    $status = Test-DockerEnvironment
    
    if ($status.Success) {
        Write-Host "✅ Docker environment is healthy" -ForegroundColor Green
        
        # Show container statuses
        foreach ($container in $status.Containers) {
            Write-Host "  - $($container.Name): " -NoNewline
            if ($container.Running -and $container.Healthy) {
                Write-Host "Running & Healthy" -ForegroundColor Green
            } elseif ($container.Running) {
                Write-Host "Running (Health unknown)" -ForegroundColor Yellow
            } else {
                Write-Host "Not Running" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "❌ Docker environment has issues: $($status.Message)" -ForegroundColor Red
        
        # Show container statuses with more detail
        foreach ($container in $status.Containers) {
            Write-Host "  - $($container.Name): " -NoNewline
            if (-not $container.Running) {
                Write-Host "Not Running" -ForegroundColor Red
            } elseif (-not $container.Healthy) {
                Write-Host "Running but Unhealthy" -ForegroundColor Yellow
            } elseif (-not $container.PortOpen) {
                Write-Host "Running but Port Not Accessible" -ForegroundColor Yellow
            } else {
                Write-Host "Running & Healthy" -ForegroundColor Green
            }
        }
    }
    
    exit [int](-not $status.Success)
}