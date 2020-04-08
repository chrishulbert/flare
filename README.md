# Flare

In short: Simple 2-way sync to a Backblaze B2 bucket across multiple computers, for cheaper-than-Dropbox storage :) 

* Unlike dropbox which always consumes ram / cpu, have this scheduled to run hourly *and then quit*.
* Backblaze gives you 2500 free requests / day, so with 8hrs/day of use, this gives you 300 folders.
* One day it would be nice to make a version that listens for updates and sends immediately.
* Or maybe just have a mini-app that watches, and if you touch anything, it debounces and spawns this to push up 1min after things slow down, and then quits again, as well as the hourly sync to pull down new stuff. Plus a menu option to 'sync now' if someone else has pushed.
* Instead of running hourly (what if you open laptop at 3:12 and close at 3:56?) - check every minute if it's been at least an hour since last run. This also solves thundering herd.
* Recommended: Set bz bucket policy to 'Keep only the last version of the file' (does that keep the 'hidden' record/file/version?)

## Getting started

You must make a config file in your home folder: `~/.flare`
This file is JSON and looks like the following:

    {
        "key": "my-backblaze-key",
        "accountId": "my-backblaze-account-id",
        "applicationKey": "my-backblaze-app-key",
        "bucketId": "my-backblaze-bucket-id",
        "bucketName": "my-backblaze-bucket-name",
        "folder":  "/Users/my-name/Flare"
    }
    
* Hidden files are deliberately not synced. Things would quickly get out of hand (eg collisions/conflicts) if we synced eg git metadata, so I simply don't do that. This also has the upside of ignoring .DS_Store nonsense.
* macOS touches folder's last modified dates whenever it changes a .DS_Store, which makes for extra work unfortunately.

## Setting up as a service

Create a file `au.com.splinter.flare.plist` with the following contents:

    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>au.com.splinter.flare</string>
            <key>Program</key>
            <string>/Users/XX/bin/flare</string>
            <key>StartCalendarInterval</key>
            <dict>
                <key>Minute</key>
                <integer>0</integer>
            </dict>
        </dict>
    </plist>
    
This will make it sync every hour on the hour. You'll need to change the 'program' value above to match where you install the flare binary.
Then: `cp au.com.splinter.flare.plist ~/Library/LaunchAgents`
Then: `launchctl load ~/Library/LaunchAgents/au.com.splinter.flare.plist`
Then: `launchctl start au.com.splinter.flare`

## License

License is MIT, which means no liability is accepted. This is just a hobby project for me. You must treat this as experimental and don't use it for important files.

## Folder modification date issues

* macOS files change last modified as you'd expect: when changing contents.
* macOS changes a folder's 'last modified' date when you add or remove or rename a file, but not when you change a file's contents.
* Worse: If you add/remove/rename a file in a folder, it doesn't affect that folder's parent folder last modified date at all.
* Windows is much the same apparently: parent-parent folders don't update dates.
* Summary: Folder last modified dates are useless.
* There used to be plenty of code in here for using folder dates to skip entire hierarchies efficiently, but that unfortunately has to be removed. 

## Folder syncing limitations

Folder syncing is very rudimentary. It should work until you try to delete a folder, at which point it'll lose metadata for that folder and assume it needs to be re-synced down.
Flare keeps track of folders that existed at the last sync, so it can guess that a folder was deleted since last sync. However, since folder modification dates are largely unhelpful, it's rudimentary.
And since the BZ api doesn't give us information about folder deletions, even if you did send a deletion 'up', another client wouldn't know to pull that deletion 'down'.
Perhaps something could be done with empty folders: If it detects that some files were deleted in a folder, and thus emptied a folder, it would presume that the folder was deleted and is to be removed locally.
However, I'm still uncomfortable with the heuristics for folder deletions because the dates are meaningless, so I'm not going to implement this.
Having said all that, if you have folders with contents, Flare will work just fine - just don't try deleting those folders. 

## File deletions

For safety, if the sync heuristics determine that a file was deleted elsewhere and needs to be deleted on your machine, it moves it into a temporary folder.
The temporary folder is: `.flare/Deleted`.
The date that the file was deleted is prefixed to its filename in the format YYYYMMDD.
After a month, it is deleted from that folder.
So if you ever lose a file, look there first!
