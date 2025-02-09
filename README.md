# Radarr-TrailerDownloader
A Python script that downloads movie trailers from Youtube for a Radarr movies library

# Requirements
- A Radarr library with naming convention starting with `{Movie Title} ({Release Year})`. If your library is using a different naming convention, feel free to edit the script to match your own convention (in the last section, and in the Get-YoutubeTrailer function)
- Python 3
- Python modules dependencies: requests, yt-dlp (run `pip install requests` and `pip install yt-dlp` to install)

# Installation
- Download and extract in a directory of your choice, visible to your Radarr installation.
- Open `config.ini` to provide your API keys and configure the script to your liking
- Highly recommended: download [ffmpeg](https://www.ffmpeg.org/) and add its `bin` folder to your PATH environment variable. Youtube now has separated audio and video almost all the time, this will ensure the script can combine them in a single trailer file with video and audio.

# Adding trailers to your existing library
In a terminal, launch `py .\TrailerDownloader.py PATH_TO_MY_LIBRARY_ROOT_FOLDER`

# Using in Radarr
In your Radarr interface, create a new Custom Script connection (Settings -> Connect -> + -> Custom Script) that triggers on import and on rename. In `Path`, enter the path to your local copy of `TrailerDownloader.py` (e.g., `C:\TrailerDownloader\TrailerDownloader.py`). If clicking the Test button works, the script will work.