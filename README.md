# Radarr-TrailerDownloader
A Windows PowerShell script that downloads movie trailers from Youtube for a Radarr movies library

# Requirements
- A Radarr library with naming convention starting with `{Movie Title} ({Release Year})`
If your library is using a different naming convention, feel free to edit the script to match your own convention (in the last section, and in the Get-YoutubeTrailer function
- Windows Powershell

# Installation
Download and extract in a directory of your choice, visible to your Radarr installation
Open `TrailerDownloader.ps1` and fill in your Youtube API key (see https://developers.google.com/youtube/v3/getting-started)

# Adding trailers to your existing library
In a PowerShell window, launch `.\TrailerDownloader.ps1 PATH_TO_MY_LIBRARY_ROOT_FOLDER` and wait for the script to finish. You can monitor download progress directly inside the most recent log file

# Using in Radarr
In your Radarr interface, create a new Custom Script connection (Settings -> Connect -> + -> Custom Script) that triggers on import and on rename. In the path, simply put the path to your local copy of the repository. If clicking the Test button works, the script will work automatically.