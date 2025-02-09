import os
import re
import sys
import requests
from urllib.parse import quote
from datetime import datetime
import yt_dlp
import configparser

############################# CONFIG #############################

# Load configuration from external file
config = configparser.ConfigParser()
config.read(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'config.ini'))

# Whether to log everything the script does
LOG_ACTIVITY = config.getboolean('CONFIG', 'LOG_ACTIVITY')

# Use fake environment variables to test the script as if it was called from Radarr
TEST_MODE_RADARR = config.getboolean('CONFIG', 'TEST_MODE_RADARR')

# Your TMDB API key, if not provided, language-dependant features won't be activated
TMDB_API_KEY = config.get('CONFIG', 'TMDB_API_KEY')

# Youtube API key (see https://developers.google.com/youtube/v3/getting-started)
YOUTUBE_API_KEY = config.get('CONFIG', 'YOUTUBE_API_KEY')

# Language-dependant parameters to search for trailers on Youtube
YOUTUBE_PARAMS = {}

# Load default parameters
YOUTUBE_PARAMS["default"] = {
    "use_original_movie_name": config.getboolean('YOUTUBE_PARAMS', 'default.use_original_movie_name'),
    "search_keywords": config.get('YOUTUBE_PARAMS', 'default.search_keywords')
}

# Load language-specific parameters
for section in config.sections():
    if section.startswith('YOUTUBE_PARAMS.') and section != 'YOUTUBE_PARAMS':
        language_code = section.split('.')[1]  # Extract language code (e.g., 'fr' from 'YOUTUBE_PARAMS.fr')
        YOUTUBE_PARAMS[language_code] = {
            "use_original_movie_name": config.getboolean(section, 'use_original_movie_name'),
            "search_keywords": config.get(section, 'search_keywords')
        }

############################# LOG #############################

# Set current directory to script location
os.chdir(os.path.dirname(os.path.abspath(__file__)))

# Create a new log file
LOG_FOLDER_NAME = "Logs"
if LOG_ACTIVITY and not os.path.exists(LOG_FOLDER_NAME):
    os.makedirs(LOG_FOLDER_NAME)

LOG_FILE_NAME = datetime.now().strftime("%Y%m%d_%H%M%S") + ".txt"
LOG_FILE_PATH = os.path.join(LOG_FOLDER_NAME, LOG_FILE_NAME)

# Echoes the given text and appends the given text to the log file's content
def log(log_text):
    print(log_text)
    if LOG_ACTIVITY:
        with open(LOG_FILE_PATH, "a") as log_file:
            log_file.write(log_text + "\n")

def log_in_function(log_text):
    print(log_text)
    if LOG_ACTIVITY:
        with open(LOG_FILE_PATH, "a") as log_file:
            log_file.write(log_text + "\n")

############################# CURL / JSON #############################

def fetch_json(url):
    log_in_function(f"Issuing web request to {url} ...")
    response = requests.get(url)
    response.raise_for_status()
    return response.json()

############################# YOUTUBE #############################

def get_youtube_trailer(movie_title, movie_year, movie_path, tmdb_id):
    trailer_filename = os.path.join(movie_path, f"{movie_title} ({movie_year})-Trailer.%(ext)s")

    # Gather data from TMDB
    keywords = YOUTUBE_PARAMS["default"]["search_keywords"]
    if TMDB_API_KEY != "YOUR_API_KEY" and tmdb_id:
        tmdb_url = f"https://api.themoviedb.org/3/movie/{tmdb_id}?api_key={TMDB_API_KEY}"
        log_in_function(f"Querying TMDB for details of movie #{tmdb_id} ...")
        tmdb_info = fetch_json(tmdb_url)

        if tmdb_info["original_language"] in YOUTUBE_PARAMS:
            keywords = YOUTUBE_PARAMS[tmdb_info["original_language"]]["search_keywords"]
            if YOUTUBE_PARAMS[tmdb_info["original_language"]]["use_original_movie_name"]:
                movie_title = tmdb_info["original_title"]
                log_in_function(f"Using original movie title: {movie_title}")

    # Search for trailer on Youtube
    yt_query = f"{movie_title} {movie_year} {keywords}"
    yt_query = quote(yt_query)

    yt_search_url = f"https://youtube.googleapis.com/youtube/v3/search?part=snippet&maxResults=1&q={yt_query}&type=video&videoDuration=short&key={YOUTUBE_API_KEY}"
    log_in_function("Sending Youtube search request ...")
    yt_search_results = fetch_json(yt_search_url)

    # Check if there are any search results
    if not yt_search_results.get("items"):
        log_in_function(f"No search results found for '{movie_title} ({movie_year})'. Skipping trailer download.")
        return 0

    yt_video_id = yt_search_results["items"][0]["id"]["videoId"]

    # Download trailer using yt-dlp library
    log_in_function("Downloading video ...")
    ydl_opts = {
        'outtmpl': trailer_filename,
        'format': 'bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4] / bv*+ba/b',
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([f"https://www.youtube.com/watch?v={yt_video_id}"])
        log_in_function(f"Trailer successfully downloaded and saved to {trailer_filename}")
        return 1
    except Exception as e:
        log_in_function(f"Failed to download trailer: {e}")
        return 0

############################# TEST MODE #############################

if TEST_MODE_RADARR:
    log("Setting TEST MODE environment")
    os.environ["radarr_eventtype"] = "Download"
    os.environ["radarr_isupgrade"] = "False"
    os.environ["radarr_movie_path"] = r"D:\PlexLibrary\Films\Bye Bye Morons (2020)"
    os.environ["radarr_movie_title"] = "Bye Bye Morons"
    os.environ["radarr_movie_year"] = "2020"
    os.environ["radarr_movie_tmdbid"] = "651881"

############################# SCRIPT #############################

# Clear screen
os.system("cls" if os.name == "nt" else "clear")

# Calling script from Radarr
if "radarr_eventtype" in os.environ:
    log("Script triggered from Radarr")

    if os.environ["radarr_eventtype"] == "Test":
        if YOUTUBE_API_KEY == "YOUR_API_KEY":
            log("Please insert your Youtube API key for the script to work")
            sys.exit(1)
        log("Test successful")

    if (os.environ["radarr_eventtype"] == "Download" and os.environ["radarr_isupgrade"] == "False") or os.environ["radarr_eventtype"] == "Rename":
        get_youtube_trailer(
            os.environ["radarr_movie_title"],
            os.environ["radarr_movie_year"],
            os.environ["radarr_movie_path"],
            os.environ["radarr_movie_tmdbid"]
        )

    sys.exit(0)

# Calling script from command line
if len(sys.argv) == 1:
    print("Usage: python DownloadTrailer.py movies_library_root_folder")
    sys.exit(0)

# Checking root folder
library_root = sys.argv[1]
if not os.path.exists(library_root):
    log("The root folder doesn't exist")
    sys.exit(1)

# Downloading trailers
downloaded_trailers_count = 0
for root, dirs, files in os.walk(library_root):
    for dir_name in dirs:
        dir_path = os.path.join(root, dir_name)
        already_has_trailer = False

        for file_name in os.listdir(dir_path):
            if file_name.lower().endswith("-trailer.mp4") or file_name.lower().endswith("-trailer.mkv"):
                already_has_trailer = True
                break

        if already_has_trailer:
            log(f'Skipping "{dir_name}" as it already has a trailer')
        else:
            log(f'Downloading a trailer for "{dir_name}" ...')

            # Extracting movie title and year from the filename
            video_files = [f for f in os.listdir(dir_path) if os.path.isfile(os.path.join(dir_path, f))]
            if video_files:
                video_file = max(video_files, key=lambda f: os.path.getsize(os.path.join(dir_path, f)))
                video_file_base = os.path.splitext(video_file)[0]

                if "tmdb-" in video_file_base:
                    match = re.match(r"(.*) \((\d{4})\).*tmdb-(\d+).*", video_file_base)
                    if match:
                        title, year, tmdb_id = match.groups()
                        downloaded_trailers_count += get_youtube_trailer(title, year, dir_path, tmdb_id)
                else:
                    match = re.match(r"(.*) \((\d{4})\)", video_file_base)
                    if match:
                        title, year = match.groups()

                        # Get TMDB Id
                        tmdb_id = ''
                        if TMDB_API_KEY != "YOUR_API_KEY":
                            tmdb_search_url = f"https://api.themoviedb.org/3/search/movie?api_key={TMDB_API_KEY}&query={quote(title)}&year={year}"
                            log(f"Searching for TMDB ID: {tmdb_search_url}")
                            tmdb_search_results = fetch_json(tmdb_search_url)
                            if tmdb_search_results["total_results"] >= 1:
                                tmdb_id = tmdb_search_results["results"][0]["id"]

                        downloaded_trailers_count += get_youtube_trailer(title, year, dir_path, tmdb_id)
                    else:
                        log("Invalid name format, skipping")

log(f"Successfully downloaded {downloaded_trailers_count} new trailers.")