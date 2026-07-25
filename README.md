### Garmin Analog Watch Face

This is a simple Garmin analog watch face for my own use. Simple, minimalistic, and clean.

#### Features

##### Time Display
Displays the current time in an analog format with hour, minute, and second hands.
Second hand is displayed only when the watch is active to save battery.

##### Date Display
Displays the current date as the small text at the bottom of the watch face in format "EEE, MM.dd".

##### Calendar Integration

This watch face can display next 12-hour events from a calendars.
Events are displayed as arcs at the edge of the watch face, with different colors for different
calendars event types.

Data is fetched automatically approximately every 5 minutes.
(if the data was not changed since last fetch, it will not be fetched again to save battery;
only one last update timestamp will be fetched instead of the whole data)

To enable this feature, you need to use external API (due to Garmin Connect API limitations watch
face cannot get calendar events directly from user's phone).

#### Thanks
- Inspired by [Analog Gradient Watch Face](https://apps.garmin.com/apps/36aaae1f-a003-4e3f-bed6-af194836f0f9)
- Guided at the beginning by [AndrewKhassapov](https://github.com/AndrewKhassapov/connect-iq)
