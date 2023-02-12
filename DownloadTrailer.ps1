############################# CONFIG #############################

# Whether to log everything the script does
$LogActivity = $true

# Use fake environment variables to test the script as if it was called from Radarr
$TestModeRadarr = $false

# Your TMDB API key, if not provided, language-dependant features won't be activated
$TmdbApiKEy = "YOUR_API_KEY";

# Youtube API key (see https://developers.google.com/youtube/v3/getting-started)
$YoutubeApiKey = "YOUR_API_KEY"

# Language-dependant parameters to search for trailers on Youtube
$YoutubeParams = @{
       fr=[pscustomobject]@{UseOriginalMovieName=$true; SearchKeywords='bande annonce'};
       default=[pscustomobject]@{UseOriginalMovieName=$false; SearchKeywords='vostfr trailer'}
   }


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

############################# CURL / JSON #############################
function fetchJSON {
    param($url)

    LogInFunction "Issuing web request to $url ..."
    $req = [System.Net.WebRequest]::Create("$url")

    $req.ContentType = "application/json; charset=utf-8"
    $req.Accept = "application/json"

    $resp = $req.GetResponse()
    $reader = new-object System.IO.StreamReader($resp.GetResponseStream())
    $responseJSON = $reader.ReadToEnd()

    $response = $responseJSON | ConvertFrom-Json
    return $response
}


############################# YOUTUBE #############################

# Searches for trailer on Youtube and downloads the video to the desired destination
function Get-YoutubeTrailer {
    param (
        $movieTitle, 
        $movieYear, 
        $moviePath,
        $tmdbId
    )

    $trailerFilename = "$moviePath\$movieTitle ($movieYear)-Trailer.%(ext)s"

    # Gather data from TMDB
    $keywords = $YoutubeParams.default.SearchKeywords;
    if($TmdbApiKEy -ne 'YOUR_API_KEY' -and $tmdbId -ne '') {
        $tmdbURL = "https://api.themoviedb.org/3/movie/$($tmdbId)?api_key=$TmdbApiKEy"
        LogInFunction "Querying TMDB for details of movie #$tmdbId ..."
        $tmdbInfo = fetchJSON($tmdbURL)

        if($YoutubeParams.ContainsKey($tmdbInfo.original_language)) {
            $keywords = $YoutubeParams[$tmdbInfo.original_language].SearchKeywords
            if($YoutubeParams[$tmdbInfo.original_language].UseOriginalMovieName) {
                $movieTitle = $tmdbInfo.original_title
                LogInFunction "Using original movie title : $movieTitle"
            }
        }
    }

    # Search for trailer on Youtube
    $ytQuery = "$movieTitle $movieYear $keywords"
    $ytQuery = [System.Web.HTTPUtility]::UrlEncode($ytQuery)

    $ytSearchUrl = "https://youtube.googleapis.com/youtube/v3/search?part=snippet&maxResults=1&q=$ytQuery&type=video&videoDuration=short&key=$YoutubeApiKey"
    LogInFunction "Sending Youtube search request ..."
    $ytSearchResults =  fetchJSON($ytSearchUrl)
    $ytVideoId = $ytSearchResults.items[0].id.videoId

    # Donwload trailer
    LogInFunction "Downloading video ..."
    & .\yt-dlp.exe -o $trailerFilename https://www.youtube.com/watch?v=$ytVideoId | Out-File -FilePath $LogFileName -Append
    LogInFunction "Trailer successfully downloaded and saved to $trailerFilename"
}


############################# TEST MODE #############################

if($TestModeRadarr) {
    Log "Setting TEST MODE environment"
    $Env:radarr_eventtype = "Download"
    $Env:radarr_isupgrade = "False"
    $Env:radarr_movie_path = "D:\PlexLibrary\Films\Bye Bye Morons (2020)"
    $Env:radarr_movie_title = "Bye Bye Morons"
    $Env:radarr_movie_year = "2020"
    $Env:radarr_movie_tmdbid = "651881"
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
        Get-YoutubeTrailer $Env:radarr_movie_title $Env:radarr_movie_year $Env:radarr_movie_path $Env:radarr_movie_tmdbid
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
            
            # Get TMDB Id
            $tmdbId = '';
            if($TmdbApiKEy -ne 'YOUR_API_KEY') {
                $tmdbSearchURL = "https://api.themoviedb.org/3/search/movie?api_key=$TmdbApiKEy&query=$([System.Web.HTTPUtility]::UrlEncode($title))&year=$year"
                Log "Searching for TMDB ID : $tmdbSearchURL"
                $tmdbSearchResultsJSON = curl $tmdbSearchURL
                $tmdbSearchResults = $tmdbSearchResultsJSON | ConvertFrom-Json
                if($tmdbSearchResults.total_results -ge 1) {
                    $tmdbId = $tmdbSearchResults.results[0].id;
                }
            }

            Get-YoutubeTrailer $title $year $_.FullName $tmdbId
            $downloadedTrailersCount++
        }
        else {
            Log "Invalid name format, skipping"
        }
    }
}
Log "Succesfully downloaded $downloadedTrailersCount new trailers."