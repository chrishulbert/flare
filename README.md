# Flare
Simple 2-way sync to Backblaze B2

* Hidden files are deliberately not synced. Things would quickly get out of hand (eg collisions/conflicts) if we synced eg git metadata, so I simply don't do that. This also has the upside of ignoring .DS_Store nonsense.
