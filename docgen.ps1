#!/usr/bin/env pwsh

##Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"

# Generate image and container names using the data in the "component.json" file
$component = Get-Content -Path "component.json" | ConvertFrom-Json

$docImage="$($component.registry)/$($component.name):$($component.version)-$($component.build)-docs"
$container=$component.name

# Remove build files
if (Test-Path "$PSScriptRoot/doc") {
    Remove-Item -Recurse -Force -Path "$PSScriptRoot/doc/*"
} else {
    New-Item -ItemType Directory -Force -Path "$PSScriptRoot/doc"
}

# Build docker image
docker build -f "$PSScriptRoot/docker/Dockerfile.docs" -t $docImage .

# Create and copy compiled files, then destroy the container
docker create --name $container $docImage
docker cp "$($container):/app/doc/." "$PSScriptRoot/doc"
docker rm $container

# Verify that docs folder was indeed created after generating documentation
if (-not (Test-Path "$PSScriptRoot/doc")) {
    Write-Error "doc folder doesn't exist in root dir. Build failed. See logs above for more information."
}