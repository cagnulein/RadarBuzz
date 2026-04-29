using Toybox.Application;
using Toybox.WatchUi;

class RadarBuzzApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [ new RadarBuzzView() ];
    }

    function onSettingsChanged() {
        WatchUi.requestUpdate();
    }
}
