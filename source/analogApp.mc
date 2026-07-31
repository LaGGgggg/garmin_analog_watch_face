import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Background;


(:background)
class CalendarBackgroundService extends System.ServiceDelegate {

    function getApiData() as Array<String> {

        var baseApiUrl = Application.Properties.getValue("CalendarApiBaseUrl") as String;
        var apiToken = Application.Properties.getValue("CalendarApiToken") as String;

        if (
            baseApiUrl == null
            || apiToken == null
            || baseApiUrl.length() == 0
            || apiToken.length() == 0
        ) {
            Background.exit({
                "success" => false,
                "reason" => "noToken",
            });
        }

        return [baseApiUrl, apiToken];
    }

    function onTemporalEvent() as Void {

        var apiData = self.getApiData();
        var baseApiUrl = apiData[0];
        var apiToken = apiData[1];

        Communications.makeWebRequest(
            baseApiUrl + "/calendar/last_update",
            null,
            {
                :method=>Communications.HTTP_REQUEST_METHOD_GET,
                :headers=>{
                    "Content-Type"=>Communications.REQUEST_CONTENT_TYPE_JSON,
                    "Webhook-Token"=>apiToken,
                },
                :responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN,
            },
            method(:onLastUpdateRequestComplete)
        );
    }

    function onLastUpdateRequestComplete(
        responseCode as Number, data as Lang.Dictionary or Lang.String or Null
    ) as Void {

        if (responseCode >= 200 && responseCode < 300) {

            if (data.equals(Application.Storage.getValue("calendarEventsLastUpdate"))) {
                Background.exit({
                    "success"=>true,
                });
            }

            var apiData = self.getApiData();
            var baseApiUrl = apiData[0];
            var apiToken = apiData[1];

            Application.Storage.setValue("calendarEventsLastUpdateTmp", data);

            Communications.makeWebRequest(
                baseApiUrl + "/calendar/24h",
                null,
                {
                    :method=>Communications.HTTP_REQUEST_METHOD_GET,
                    :headers=>{
                        "Content-Type"=>Communications.REQUEST_CONTENT_TYPE_JSON,
                        "Webhook-Token"=>apiToken,
                    },
                },
                method(:onCalendarEventsRequestComplete)
            );
        } else {
            Background.exit({
                "success"=>false,
                "reason"=>"badResponse",
                "responseCode"=>responseCode,
            });
        }
    }

    function onCalendarEventsRequestComplete(
        responseCode as Number, data as Lang.Dictionary or Lang.String or Null
    ) as Void {

        if (responseCode >= 200 && responseCode < 300) {

            Application.Storage.setValue(
                "calendarEventsLastUpdate",
                Application.Storage.getValue("calendarEventsLastUpdateTmp")
            );
            Application.Storage.deleteValue("calendarEventsLastUpdateTmp");

            Background.exit({
                "success"=>true,
                "calendarEvents"=>data,
            });

        } else {
            Background.exit({
                "success"=>false,
                "reason"=>"badResponse",
                "responseCode"=>responseCode,
            });
        }
    }
}


(:background)
class analogApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        // 60 * 5 + 1 = 301 (5 min + 1 second)
        Background.registerForTemporalEvent(new Time.Duration(301));
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new analogView()];
    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new CalendarBackgroundService()];
    }

    function onBackgroundData(data) as Void {

        if (data instanceof Lang.Dictionary && data.hasKey("calendarEvents")) {
            Application.Storage.setValue("calendarEvents", data["calendarEvents"]);
        }

        WatchUi.requestUpdate();
    }
}

function getApp() as analogApp {
    return Application.getApp() as analogApp;
}
