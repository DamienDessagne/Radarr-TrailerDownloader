############################# CONFIG #############################

# Whether to log everything the script does
$LogActivity = $true

# Use fake environment variables to test the script as if it was called from Radarr
$TestModeRadarr = $false

# Youtube API key (see https://developers.google.com/youtube/v3/getting-started)
$YoutubeApiKey = "YOUR_API_KEY"

# Additionnal keywords to search for trailers on Youtube (ex: "vost fr" for french subbed trailers)
$YoutubeKeywords = ""


############################# IMPORTS #############################

Add-Type -AssemblyName System.Web


############################# LOG #############################

# Set current directory to script location :
$MyInvocation.MyCommand.Path | Split-Path | Push-Location

# Create a new log file
$LogFolderName = "Logs"
if($LogActivity -and -not(Test-Path $LogFolderName)) {
    New-Item $LogFolderName -ItemType Directory
}
$LogFileName = Get-Date -Format FileDateTime
$LogFileName = "$LogFolderName/$LogFileName.txt"

# Echoes the given text and appends the given text to the log file's content
function Log {
    param ($LogText)

    echo $LogText
    if($LogActivity) {
        $LogText >> $LogFileName
    }
}

#
function LogInFunction {
    param($LogText)

    Write-Information $LogText -InformationAction Continue
    if($LogActivity) {
        $LogText >> $LogFileName
    }
}


############################# YOUTUBE #############################

# Searches for trailer on Youtube and downloads the video to the desired destination
function Get-YoutubeTrailer {
    param (
        $movieTitle, 
        $movieYear, 
        $moviePath
    )

    # Search for trailer on Youtube
    $ytQuery = "$movieTile $movieYear $YoutubeKeywords trailer"
    $ytQuery = [System.Web.HTTPUtility]::UrlEncode($ytQuery)

    $ytSearchUrl = "https://youtube.googleapis.com/youtube/v3/search?part=snippet&maxResults=1&q=$ytQuery&type=video&videoDuration=short&key=$YoutubeApiKey"
    LogInFunction "Sending Youtube search request : $ytSearchUrl ..."
    
    $ytSearchResultsJSON = curl $ytSearchUrl

    $ytSearchResults = $ytSearchResultsJSON | ConvertFrom-Json
    $ytVideoId = $ytSearchResults.items[0].id.videoId

    # Donwload trailer
    LogInFunction "Downloading video ..."
    $trailerFilename = "$moviePath\$movieTitle ($movieYear) Trailer.%(ext)s"
    & .\youtube-dl.exe -o $trailerFilename $ytVideoId | Out-File -FilePath $LogFileName -Append
    LogInFunction "Trailer successfully downloaded and saved to $trailerFilename"
}


############################# TEST MODE #############################

if($TestModeRadarr) {
    Log "Setting TEST MODE environment"
    $Env:radarr_eventtype = "Download"
    $Env:radarr_isupgrade = "False"
    $Env:radarr_movie_path = "D:\PlexLibrary\Films\Ex Machina (2015)"
    $Env:radarr_movie_title = "Ex Machina"
    $Env:radarr_movie_year = "2015"
}


############################# SCRIPT #############################

cls

# Calling script from Radarr
if(Test-Path Env:radarr_eventtype) {
    Log "Script triggered from Radarr"

    if($Env:radarr_eventtype -eq "Test") {
        if($YoutubeApiKey -eq "YOUR_API_KEY") {
            Log "Please insert your Youtube API key for the script to work"
            exit 1
        }
        Log "Test successful"
    }
    
    if(($Env:radarr_eventtype -eq "Download" -and $Env:radarr_isupgrade -eq "False") -or $Env:radarr_eventtype -eq "Rename") {
        Get-YoutubeTrailer $Env:radarr_movie_title $Env:radarr_movie_year $Env:radarr_movie_path
    }
    
    exit 0
}

# Calling script from command line 
if($args.Count -eq 0) {
    echo "Usage : .\DownloadTrailer.ps1 movies_library_root_folder"
    exit 0
}

# Checking root folder
$libraryRoot = $args[0]
if(-not(Test-Path $libraryRoot)) {
    Log "The root folder doesn't exist"
    exit 1
}

# Downloading trailers
$downloadedTrailersCount = 0
Get-ChildItem -Path $libraryRoot -Directory |
ForEach-Object {
    $alreadyHasTrailer = $false
    Get-ChildItem -LiteralPath "$($_.FullName)" -File -Exclude *part -Filter "*Trailer.*" |
    ForEach-Object {
        if($_.Extension -ne ".part") {
            $alreadyHasTrailer = $true
        }
    }

    if($alreadyHasTrailer) {
        Log "Skipping ""$($_.Name)"" as it already has a trailer"
    }
    else {
        Log "Downloading a trailer for ""$($_.Name)"" ..."
        
        # Extracting movie title and year from the filename
        $videoFile = Get-ChildItem -LiteralPath "$($_.FullName)" -File | Sort-Object Length -Descending | Select-Object BaseName -First 1
        if($videoFile.BaseName -match "(.*) \((\d{4})\)") {
            $title = $Matches.1
            $year = $Matches.2
            
            Get-YoutubeTrailer $title $year $_.FullName
            $downloadedTrailersCount++
        }
        else {
            Log "Invalid name format, skipping"
        }
    }
}
Log "Succesfully downloaded $downloadedTrailersCount new trailers."