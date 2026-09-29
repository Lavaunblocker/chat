GlobeChat v1.1

This build is based on the exact v1.1 ZIP supplied in chat.
Announcements have been removed from the webpage.

NEW: profile pictures
- Account & profile lets each signed-in user upload or remove their own picture.
- PNG/JPG/WEBP/GIF only, maximum 5 MB.
- Pictures are tied to the user's Supabase UUID and therefore follow the account across devices.
- Messages show the sender's current profile picture.
- If no picture is set, GlobeChat shows the first letter of the username.
- Run upgrade-profile-pictures.sql once before using the feature.

Existing message pagination/history logic is otherwise preserved.

UI FIX:
- Account/profile entry is labeled "Account & Profile".
- Profile picture upload/remove controls are inside that panel.
- Username cooldown/change controls remain in that panel.
- Log out is restored and visible at the bottom of that panel.
- No additional SQL is required after the profile-picture SQL succeeded.

PROFILE/DISPLAY NAME FIX
- Display name: change anytime, 1-40 characters.
- Username: remains unique and uses the existing 7-day cooldown.
- Messages show Display Name @username.
- Profile picture storage was changed to public-read/owner-write because profile pictures are public profile data.
- PFP uploads use unique filenames to avoid stale cached avatars.
- Run upgrade-display-name-pfp-fix.sql once.
