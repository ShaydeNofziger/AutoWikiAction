param (
    [string]$RepoOwner,
    [string]$RepoName,
    [int]$PrNumber,
    [string]$OpenAiApiKey,
    [string]$GitHubToken
)

$ErrorActionPreference = "Stop"

function Get-PullRequestInfo {
    param (
        [string]$Owner,
        [string]$Repo,
        [int]$PR,
        [string]$Token
    )

    $headers = @{ Authorization = "Bearer $Token"; "User-Agent" = "AutoWikiBot" }

    $prUrl = "https://api.github.com/repos/$Owner/$Repo/pulls/$PR"
    $filesUrl = "https://api.github.com/repos/$Owner/$Repo/pulls/$PR/files"

    $pullrequest = Invoke-RestMethod -Uri $prUrl -Headers $headers
    $files = Invoke-RestMethod -Uri $filesUrl -Headers $headers

    return @{
        Title = $pullrequest.title
        Body = $pullrequest.body
        Files = $files | ForEach-Object { $_.filename }
    }
}

function Generate-MarkdownFromOpenAI {
    param (
        [string]$Title,
        [string]$Body,
        [array]$Files,
        [string]$ApiKey
    )

    $prompt = @"
Respond only with raw GitHub-flavored Markdown. Do not wrap your response in triple backticks.

Title: $Title
Description: $Body
Files Changed: $($Files -join ", ")

Write a brief wiki update summarizing the purpose of this PR, key changes, and any usage instructions.
"@

    $headers = @{
        Authorization = "Bearer $ApiKey"
        "Content-Type" = "application/json"
    }

    $body = @{
        model = "gpt-4"
        messages = @(
            @{ role = "system"; content = "You are a technical writer generating Markdown documentation." },
            @{ role = "user"; content = $prompt }
        )
        temperature = 0.3
    } | ConvertTo-Json -Depth 5

    $response = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers $headers -Body $body
    return $response.choices[0].message.content.Trim()
}

function Push-ToWiki {
    param (
        [string]$RepoOwner,
        [string]$RepoName,
        [string]$PageName,
        [string]$MarkdownContent,
        [string]$Token
    )

    git config --global credential.helper store
    git config --global core.askPass "echo"

    $wikiUrl = "https://x-access-token:$Token@github.com/$RepoOwner/$RepoName.wiki.git"

    $tempDir = Join-Path $env:TEMP ("wiki-" + [guid]::NewGuid())

    git clone $wikiUrl $tempDir

    Push-Location $tempDir
    $branch = git symbolic-ref refs/remotes/origin/HEAD 2>$null | ForEach-Object {
        $_ -replace 'refs/remotes/origin/', ''
    }
    if (-not $branch) { $branch = "master" }

    $filePath = Join-Path $tempDir $PageName
    Set-Content -Path $filePath -Value $MarkdownContent -Encoding UTF8

    git config user.email "autowikibot@localhost"
    git config user.name "AutoWikiBot"
    git add $PageName

    git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host "No wiki changes detected for $PageName"
    }
    else {
        git commit -m "Auto-update: $PageName"
        git push origin $branch
    }
    Pop-Location

    Remove-Item -Path $tempDir -Recurse -Force
}

# === MAIN FLOW ===

$pr = Get-PullRequestInfo -Owner $RepoOwner -Repo $RepoName -PR $PrNumber -Token $GitHubToken

if ($pr.Title -match "\[skip wiki\]") {
    Write-Host "Skipping wiki update for PR $PrNumber due to [skip wiki] tag in title."
    exit 0
}

$markdown = Generate-MarkdownFromOpenAI -Title $pr.Title -Body $pr.Body -Files $pr.Files -ApiKey $OpenAiApiKey

$pageName = "PR-$PrNumber.md"
Push-ToWiki -RepoOwner $RepoOwner -RepoName $RepoName -PageName $pageName -MarkdownContent $markdown -Token $GitHubToken
Write-Host "✅ Wiki updated with PR $PrNumber"
