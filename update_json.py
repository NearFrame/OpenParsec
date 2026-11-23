import json
import plistlib
import re
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from zipfile import ZipFile

def prepare_description(text):
    text = re.sub('<[^<]+?>', '', text) # Remove HTML tags
    text = re.sub(r'#{1,6}\s?', '', text) # Remove markdown header tags
    text = re.sub(r'\*{2}', '', text) # Remove all occurrences of two consecutive asterisks
    text = re.sub(r'(?<=\r|\n)-', '•', text) # Only replace - with • if it is preceded by \r or \n
    text = re.sub(r'`', '"', text) # Replace ` with "
    text = re.sub(r'\r\n\r\n', '\r \n', text) # Replace \r\n\r\n with \r \n (avoid incorrect display of the description regarding paragraphs)
    return text

def fetch_latest_release(repo_url):
    import requests

    api_url = f"https://api.github.com/repos/{repo_url}/releases"
    headers = {
        "Accept": "application/vnd.github+json",
    }
    if os.environ.get("GITHUB_TOKEN"):
        headers["Authorization"] = f"Bearer {os.environ['GITHUB_TOKEN']}"
    try:
        response = requests.get(api_url, headers=headers)
        response.raise_for_status()
        release = response.json()
        return release
    except requests.RequestException as e:
        print(f"Error fetching releases: {e}")
        raise

def get_file_size(url):
    import requests

    try:
        response = requests.head(url)
        response.raise_for_status()
        return int(response.headers.get('Content-Length', 0))
    except requests.RequestException as e:
        print(f"Error getting file size: {e}")
        return 194586

def update_json_file_release(json_file, latest_release):
    if isinstance(latest_release, list) and latest_release:
        latest_release = latest_release[0]
    else:
        print("Error getting latest release")
        return

    try:
        with open(json_file, "r") as file:
            data = json.load(file)
    except json.JSONDecodeError as e:
        print(f"Error reading JSON file: {e}")
        data = {"apps": []}
        raise

    app = data["apps"][0]

    full_version = latest_release["tag_name"]
    tag = latest_release["tag_name"]
    version = re.search(r"(\d+\.\d+\.\d+)", full_version).group(1)
    version_date = latest_release["published_at"]
    date_obj = datetime.strptime(version_date, "%Y-%m-%dT%H:%M:%SZ")
    version_date = date_obj.strftime("%Y-%m-%d")

    description = latest_release["body"]
    description = prepare_description(description)

    assets = latest_release.get("assets", [])
    download_url = None
    size = None
    for asset in assets:
        if asset["name"] == f"OpenParsec.ipa":
            download_url = asset["browser_download_url"]
            size = asset["size"]
            break

    if download_url is None or size is None:
        print("Error: IPA file not found in release assets.")
        return

    version_entry = {
        "version": version,
        "date": version_date,
        "localizedDescription": description,
        "downloadURL": download_url,
        "size": size
    }

    duplicate_entries = [item for item in app["versions"] if item["version"] == version]
    if duplicate_entries:
        app["versions"].remove(duplicate_entries[0])

    app["versions"].insert(0, version_entry)

    app.update({
        "version": version,
        "versionDate": version_date,
        "versionDescription": description,
        "downloadURL": download_url,
        "size": size
    })

    if "news" not in data:
        data["news"] = []

    news_identifier = f"release-{full_version}"
    date_string = date_obj.strftime("%d/%m/%y")
    news_entry = {
        "appID": "com.aigch.OpenParsec",
        "caption": f"Update of OpenParsec just got released!",
        "date": latest_release["published_at"],
        "identifier": news_identifier,
        "imageURL": "https://raw.githubusercontent.com/hugeBlack/OpenParsec/main/screenshots/release.png",
        "notify": True,
        "tintColor": "#0784FC",
        "title": f"{full_version} - OpenParsec  {date_string}",
        "url": f"https://github.com/hugeBlack/OpenParsec/releases/tag/{tag}"
    }

    news_entry_exists = any(item["identifier"] == news_identifier for item in data["news"])
    if not news_entry_exists:
        data["news"].append(news_entry)

    try:
        with open(json_file, "w") as file:
            json.dump(data, file, indent=2)
        print("JSON file updated successfully.")
    except IOError as e:
        print(f"Error writing to JSON file: {e}")
        raise

def git_output(*args):
    return subprocess.check_output(["git", *args], encoding="utf-8").strip()


def update_json_file_nightly(json_file, ipa_file):
    data = json.loads(json_file.read_text(encoding="utf-8"))
    app = data["apps"][0]

    with ZipFile(ipa_file) as ipa:
        plist_path = f"Payload/{ipa_file.stem}.app/Info.plist"
        info_plist = plistlib.loads(ipa.read(plist_path))
    if info_plist["CFBundleIdentifier"] != app["bundleIdentifier"]:
        raise ValueError("The IPA bundle identifier does not match the AltStore source")

    version = info_plist["CFBundleShortVersionString"]
    build_number = info_plist["CFBundleVersion"]
    version_date = datetime.now(timezone.utc).isoformat(timespec="seconds")
    repository = f"{os.environ['GITHUB_SERVER_URL']}/{os.environ['GITHUB_REPOSITORY']}"
    download_url = f"{repository}/releases/download/nightly/{ipa_file.name}"
    size = ipa_file.stat().st_size

    commit_sha = git_output("rev-parse", "--short", "HEAD")
    headline = git_output("log", "-1", "--format=%s", "HEAD")
    changes = ""
    if git_output("tag", "--list", "nightly"):
        changes = git_output("log", "--no-merges", "--format=- %s", "refs/tags/nightly..HEAD")
    if not changes:
        changes = f"- {headline}"

    description = (
        f"OpenParsec {version} (build {build_number})\n\n"
        f"{changes}\n\n"
        f"Build details: {os.environ['NIGHTLY_LINK']}\n"
    )

    app["versions"] = [{
        "version": version,
        "buildVersion": build_number,
        "buildNumber": build_number,
        "date": version_date,
        "localizedDescription": description,
        "downloadURL": download_url,
        "size": size,
        "minOSVersion": info_plist["MinimumOSVersion"],
        "commit": commit_sha,
        "headline": headline,
    }]
    app.update({
        "version": version,
        "versionDate": version_date,
        "versionDescription": description,
        "downloadURL": download_url,
        "size": size,
        "commit": commit_sha,
        "headline": headline,
    })
    data["news"] = []

    json_file.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    Path("nightly-notes.md").write_text(description, encoding="utf-8")


def main():
    if "NIGHTLY_LINK" in os.environ:
        update_json_file_nightly(Path("altstore.json"), Path(os.environ["NIGHTLY_IPA"]))
    else:
        repo_url = os.environ.get("GITHUB_REPOSITORY", "hugeBlack/OpenParsec")
        update_json_file_release("apps.json", fetch_latest_release(repo_url))


if __name__ == "__main__":
    main()
