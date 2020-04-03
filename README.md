# Flare
Simple 2-way sync to Backblaze B2

* Hidden files are deliberately not synced. Things would quickly get out of hand (eg collisions/conflicts) if we synced eg git metadata, so I simply don't do that. This also has the upside of ignoring .DS_Store nonsense.
* macOS touches folder's last modified dates whenever it changes a .DS_Store, which makes for extra work unfortunately.

## Folder modification date issues

* macOS files change last modified as you'd expect: when changing contents.
* macOS changes a folder's 'last modified' date when you add or remove or rename a file, but not when you change a file's contents.
* Worse: If you add/remove/rename a file in a folder, it doesn't affect that folder's parent folder last modified date at all.
* Windows is much the same apparently: parent-parent folders don't update dates.
* Summary: Folder last modified dates are useless.
* There used to be plenty of code in here for using folder dates to skip entire hierarchies efficiently, but that unfortunately has to be removed. 
