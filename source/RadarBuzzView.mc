using Toybox.AntPlus;
using Toybox.Application;
using Toybox.Attention;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

class RadarBuzzListener extends AntPlus.BikeRadarListener {

    hidden var mView;

    function initialize(view) {
        BikeRadarListener.initialize();
        mView = view;
    }

    function onBikeRadarUpdate(data) {
        mView.onRadarUpdate(data);
    }

    function onDeviceStateUpdate(data) {
        mView.onRadarStateUpdate(data);
    }
}

class RadarBuzzView extends WatchUi.SimpleDataField {

    hidden const DEFAULT_NEAR_THRESHOLD_METERS = 10.0;
    hidden const DEFAULT_MID_THRESHOLD_METERS = 25.0;

    hidden var mRadar;
    hidden var mListener;
    hidden var mTargets;
    hidden var mRadarState;
    hidden var mLastBuzzStamp;
    hidden var mTimerRunning;

    function initialize() {
        SimpleDataField.initialize();
        label = "RadarBuzz";

        mTargets = [];
        mRadarState = AntPlus.DEVICE_STATE_CLOSED;
        mLastBuzzStamp = null;
        mTimerRunning = false;

        mListener = new RadarBuzzListener(self);
        mRadar = new AntPlus.BikeRadar(mListener);
    }

    function compute(info) {
        var nearest = getNearestTarget();
        maybeBuzz(nearest);

        if (mRadarState == AntPlus.DEVICE_STATE_DEAD) {
            return "PAIR";
        }

        if (mRadarState == AntPlus.DEVICE_STATE_SEARCHING) {
            return "SCAN";
        }

        if (nearest == null) {
            return "CLEAR";
        }

        return nearest[:rangeText] + " " + mTargets.size().format("%d");
    }

    function onTimerStart() {
        mTimerRunning = true;
    }

    function onTimerResume() {
        mTimerRunning = true;
    }

    function onTimerPause() {
        mTimerRunning = false;
    }

    function onTimerStop() {
        mTimerRunning = false;
    }

    function onTimerReset() {
        mTimerRunning = false;
        mLastBuzzStamp = null;
    }

    function onRadarUpdate(data) {
        mTargets = data == null ? [] : data;
        WatchUi.requestUpdate();
    }

    function onRadarStateUpdate(data) {
        mRadarState = data;
        WatchUi.requestUpdate();
    }

    hidden function getNearestTarget() {
        if (mTargets == null || mTargets.size() == 0) {
            return null;
        }

        var nearest = null;
        foreach (var target in mTargets) {
            if (target == null) {
                continue;
            }

            if (nearest == null || target.range < nearest.range) {
                nearest = target;
            }
        }

        if (nearest == null) {
            return null;
        }

        return {
            :range => nearest.range,
            :rangeText => nearest.range.format("%.0fm"),
            :threat => nearest.threat
        };
    }

    hidden function maybeBuzz(nearest) {
        if (!mTimerRunning || nearest == null || !(Attention has :vibrate)) {
            if (nearest == null) {
                mLastBuzzStamp = null;
            }
            return;
        }

        var now = System.getClockTime();
        var stamp = now.hour.format("%02d") + now.min.format("%02d") + now.sec.format("%02d");
        if (mLastBuzzStamp == stamp) {
            return;
        }

        Attention.vibrate(buildPattern(nearest[:range]));
        mLastBuzzStamp = stamp;
    }

    hidden function buildPattern(range) {
        var thresholds = getThresholds();
        if (range <= thresholds[:near]) {
            return [
                new Attention.VibeProfile(100, 220),
                new Attention.VibeProfile(0, 100),
                new Attention.VibeProfile(100, 220),
                new Attention.VibeProfile(0, 100),
                new Attention.VibeProfile(100, 220)
            ];
        }

        if (range <= thresholds[:mid]) {
            return [
                new Attention.VibeProfile(75, 260),
                new Attention.VibeProfile(0, 120),
                new Attention.VibeProfile(75, 260)
            ];
        }

        return [
            new Attention.VibeProfile(55, 350)
        ];
    }

    hidden function getThresholds() {
        var near = getNumericProperty("nearThresholdMeters", DEFAULT_NEAR_THRESHOLD_METERS);
        var mid = getNumericProperty("midThresholdMeters", DEFAULT_MID_THRESHOLD_METERS);

        if (near < 1.0) {
            near = DEFAULT_NEAR_THRESHOLD_METERS;
        }

        if (mid <= near) {
            mid = near + 1.0;
        }

        return {
            :near => near,
            :mid => mid
        };
    }

    hidden function getNumericProperty(key, fallback) {
        var value = Application.getApp().getProperty(key);
        if (value == null || !(value instanceof Lang.Number)) {
            return fallback;
        }

        return value.toFloat();
    }
}
