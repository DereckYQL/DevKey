function Get-DevKeyTemplateFiles {
    param([int]$Index,[string]$Name)
    $packageName=($Name.ToLowerInvariant() -replace '[^a-z0-9-]','-' -replace '-+','-').Trim('-')
    if(-not $packageName){$packageName='devkey-project'}
    if($packageName.Length -gt 200){$packageName=$packageName.Substring(0,200)}
    $jsonPackageName=ConvertTo-Json -InputObject $packageName -Compress
    switch ($Index) {
        1 { return @(
            @{Name='index.html';Content='<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>__HTMLNAME__</title><link rel="stylesheet" href="style.css"></head><body><main><h1>__HTMLNAME__</h1></main><script src="app.js"></script></body></html>'},
            @{Name='style.css';Content=':root { font-family: system-ui, sans-serif; } body { margin: 2rem; }'},
            @{Name='app.js';Content="'use strict';`nconsole.log('Ready');"}) }
        2 { return @(
            @{Name='package.json';Content=('{"name":'+$jsonPackageName+',"version":"1.0.0","private":true,"scripts":{"start":"node index.js"}}')},
            @{Name='index.js';Content="'use strict';`nconsole.log('Hello from '+__JSNAME__);"}) }
        3 { return @(
            @{Name='package.json';Content=('{"name":'+$jsonPackageName+',"version":"1.0.0","private":true,"scripts":{"start":"vite"}}')},
            @{Name='index.html';Content='<div id="root"></div><script type="module" src="/src.jsx"></script>'},
            @{Name='src.jsx';Content="import React from 'react';`nimport { createRoot } from 'react-dom/client';`nconst name=__JSNAME__;`ncreateRoot(document.getElementById('root')).render(<h1>{name}</h1>);"}) }
        4 { return @(
            @{Name='package.json';Content=('{"name":'+$jsonPackageName+',"version":"1.0.0","private":true,"scripts":{"dev":"next dev","build":"next build"}}')},
            @{Name='app/page.jsx';Content='export default function Page() { return <main><h1>__HTMLNAME__</h1></main>; }'},
            @{Name='app/layout.jsx';Content='export const metadata = { title: "__HTMLNAME__" }; export default function RootLayout({ children }) { return <html lang="es"><body>{children}</body></html>; }'}) }
        5 { return @(
            @{Name='main.py';Content="def main():`n    print('Hello from ' + __PYNAME__)`n`nif __name__ == '__main__':`n    main()"},
            @{Name='requirements.txt';Content='# Add reviewed dependencies here.'}) }
        6 { return @(
            @{Name='__NAME__.csproj';Content='<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable></PropertyGroup></Project>'},
            @{Name='Program.cs';Content='Console.WriteLine("Hello from __NAME__!");'}) }
    }
}
function New-DevKeyProjectFromTemplate {
    $templates=@('HTML/CSS/JavaScript','Node.js','React','Next.js','Python','C#')
    for($i=0;$i -lt $templates.Count;$i++){Write-Host (" [{0}] {1}" -f ($i+1),$templates[$i])}
    $index=0;if(-not[int]::TryParse((Read-Host 'Plantilla (0 cancela)'),[ref]$index) -or $index -lt 1 -or $index -gt $templates.Count){return}
    $name=Read-Host 'Nombre del proyecto'
    try {
        $path=Get-DevKeySafeProjectPath $name
        if(Test-Path -LiteralPath $path){throw 'El destino ya existe.'}
        $files=@(Get-DevKeyTemplateFiles -Index $index -Name $name)
        foreach($file in $files){$destination=Join-Path $path ($file.Name.Replace('__NAME__',$name));$parent=Split-Path -Parent $destination;if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};$content=[string]$file.Content.Replace('__NAME__',$name).Replace('__HTMLNAME__',[Net.WebUtility]::HtmlEncode($name)).Replace('__JSNAME__',(ConvertTo-Json -InputObject $name -Compress)).Replace('__PYNAME__',(ConvertTo-Json -InputObject $name -Compress));Set-Content -LiteralPath $destination -Value $content -Encoding UTF8 -ErrorAction Stop}
        $dependencyNote=switch($index){1{'No external dependencies.'}2{'Requires Node.js.'}3{'Requires Node.js plus react, react-dom, and Vite.'}4{'Requires Node.js plus Next.js, React, and React DOM.'}5{'Requires Python 3; add reviewed packages to requirements.txt.'}6{'Requires the .NET 8 SDK.'}}
        Set-Content -LiteralPath (Join-Path $path 'README.md') -Value ("# $name`n`nTemplate: $($templates[$index-1]). $dependencyNote`n`nReview dependencies before installing them. DevKey does not install packages automatically.`n") -Encoding UTF8
        Write-DevKeyLog -Log maintenance.log -Message "Project created from template: $name";Write-Host 'Plantilla creada. Revisa sus dependencias antes de instalarlas.' -ForegroundColor Green
    } catch { Write-Host $_.Exception.Message -ForegroundColor Red }
    Pause-DevKey
}
